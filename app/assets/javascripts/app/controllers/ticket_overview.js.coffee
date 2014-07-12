class Index extends App.Controller
  constructor: ->
    super
    @render()

  render: ->

    @html App.view('agent_ticket_view')()

    if !@view
      cache = App.Store.get( 'navupdate_ticket_overview' )
      if cache && cache[0]
        @view = cache[0].link

    new Navbar(
      el:   @el.find('.sidebar')
      view: @view
    )

    new Table(
      el:   @el.find('.main')
      view: @view
    )

class Table extends App.ControllerContent
  events:
    'click [data-type=edit]':      'zoom'
    'click [data-type=settings]':  'settings'
    'click [data-type=viewmode]':  'viewmode'
    'click [data-type=page]':      'page'

  constructor: ->
    super

    # check authentication
    return if !@authenticate()

    @view_mode = localStorage.getItem( "mode:#{@view}" ) || 's'
    @log 'notice', 'view:', @view, @view_mode

    # set title
    @title ''
    @navupdate '#ticket/view'

    @meta = {}
    @bulk = {}

    # set new key
    @key = 'ticket_overview_' + @view

    # bind to rebuild view event
    @bind( 'ticket_overview_rebuild', @fetch )

    # render
    @fetch()

  fetch: (force) =>

    # use cache of first page
    cache = App.Store.get( @key )
    if !force && cache
      @load(cache)

    # init fetch via ajax, all other updates on time via websockets
    else
      @ajax(
        id:    'ticket_overview_' + @key,
        type:  'GET',
        url:   @apiPath + '/ticket_overviews',
        data:  {
          view:       @view,
          view_mode:  @view_mode,
        }
        processData: true,
        success: (data) =>
          data.ajax = true
          @load(data)
        )

  load: (data) =>
    return if !data
    return if !data.ticket_ids
    return if !data.overview

    @overview      = data.overview
    @tickets_count = data.tickets_count
    @ticket_ids    = data.ticket_ids

    if data.ajax
      data.ajax = false
      App.Store.write( @key, data )

      # load assets
      App.Collection.loadAssets( data.assets )

    # get meta data
    @overview = data.overview
    App.Overview.refresh( @overview, { clear: true } )

    App.Overview.unbind('local:rerender')
    App.Overview.bind 'local:rerender', (record) =>
      @log 'notice', 'rerender...', record
      @render()

    App.Overview.unbind('local:refetch')
    App.Overview.bind 'local:refetch', (record) =>
      @log 'notice', 'refetch...', record
      @fetch(true)

    @ticket_list_show = []
    for ticket_id in @ticket_ids
      @ticket_list_show.push App.Ticket.retrieve( ticket_id )

    # remeber bulk attributes
    @bulk = data.bulk

    # set cache
#    App.Store.write( @key, data )

    # render page
    @render()

  render: ->



    # if customer and no ticket exists, show the following message only
    if !@ticket_list_show[0] && @isRole('Customer')
      @html App.view('customer_not_ticket_exists')()
      return

    @selected = @bulkGetSelected()

    # set page title
    @overview = App.Overview.find( @overview.id )
    @title @overview.name

    # render init page
    checkbox = true
    edit     = true
    if @isRole('Customer')
      checkbox = false
      edit     = false
    view_modes = [
      {
        name:  'S'
        type:  's'
        class: 'active' if @view_mode is 's'
      },
      {
        name:  'M'
        type:  'm'
        class: 'active' if @view_mode is 'm'
      }
    ]
    if @isRole('Customer')
      view_modes = []
    html = App.view('agent_ticket_view/content')(
      overview:    @overview
      view_modes:  view_modes
      checkbox:    checkbox
      edit:        edit
    )
    html = $(html)
#    html.find('li').removeClass('active')
#    html.find("[data-id=\"#{@start_page}\"]").parents('li').addClass('active')

    @html html

    # create table/overview
    table = ''
    if @view_mode is 'm'
      table = App.view('agent_ticket_view/detail')(
        overview: @overview
        objects:  @ticket_list_show
        checkbox: checkbox
      )
      table = $(table)
      table.delegate('[name="bulk_all"]', 'click', (e) ->
        if $(e.target).attr('checked')
          $(e.target).parents().find('[name="bulk"]').attr('checked', true)
        else
          $(e.target).parents().find('[name="bulk"]').attr('checked', false)
      )
      @el.find('.table-overview').append(table)
    else
      openTicket = (id,e) =>
        ticket = App.Ticket.retrieve(id)
        @navigate ticket.uiUrl()
      callbackTicketTitleAdd = (value, object, attribute, attributes, refObject) =>
        attribute.title = object.title
        value
      callbackLinkToTicket = (value, object, attribute, attributes, refObject) =>
        attribute.link = object.uiUrl()
        value
      callbackUserPopover = (value, object, attribute, attributes, refObject) =>
        attribute.class = 'user-popover'
        attribute.data =
          id: refObject.id
        value
      callbackCheckbox = (id, checked, e) =>
        if @el.find('table').find('input[name="bulk"]:checked').length == 0
          @el.find('.bulk-action').addClass('hide')
        else
          @el.find('.bulk-action').removeClass('hide')

      new App.ControllerTable(
        overview:     @overview.view.s
        el:           @el.find('.table-overview')
        model:        App.Ticket
        objects:      @ticket_list_show
        checkbox:     checkbox
        groupBy:      @overview.group_by
        bindRow:
          events:
            'click':  openTicket
        #bindCol:
        #  customer_id:
        #    events:
        #      'mouseover': popOver
        callbackAttributes:
          customer_id:
            [ callbackUserPopover ]
          owner_id:
            [ callbackUserPopover ]
          title:
            [ callbackLinkToTicket, callbackTicketTitleAdd ]
          number:
            [ callbackLinkToTicket, callbackTicketTitleAdd ]
        bindCheckbox:
          events:
            'click':  callbackCheckbox
      )

    @bulkSetSelected( @selected )

    # start user popups
    @userPopups()

    # show frontend times
    @frontendTimeUpdate()

    # start bulk action observ
    @el.find('.bulk-action').append( @bulk_form() )
    if @el.find('.table-overview').find('input[name="bulk"]:checked').length isnt 0
        @el.find('.bulk-action').removeClass('hide')

    # show/hide bulk action
    @el.find('.table-overview').delegate('input[name="bulk"], input[name="bulk_all"]', 'click', (e) =>
      console.log('YES')
      if @el.find('.table-overview').find('input[name="bulk"]:checked').length == 0

        # hide
        @el.find('.bulk-action').addClass('hide')
      else

        # show
        @el.find('.bulk-action').removeClass('hide')
    )

    # deselect bulk_all if one item is uncheck observ
    @el.find('.table-overview').delegate('[name="bulk"]', 'click', (e) =>
      if !$(e.target).attr('checked')
        $(e.target).parents().find('[name="bulk_all"]').attr('checked', false)
    )

  page: (e) =>
    e.preventDefault()
    id = $(e.target).data('id')
    @start_page = id
    @fetch()

  viewmode: (e) =>
    e.preventDefault()
    @start_page    = 1
    mode = $(e.target).data('mode')
    @view_mode = mode
    localStorage.setItem( "mode:#{@view}", mode )
    @fetch()
    @render()

  bulk_form: =>
    @configure_attributes_ticket = [
      { name: 'state_id',     display: 'State',    tag: 'select',   multiple: false, null: true, relation: 'TicketState', filter: @bulk, translate: true, nulloption: true, default: '', class: 'span2', item_class: 'pull-left' },
      { name: 'priority_id',  display: 'Priority', tag: 'select',   multiple: false, null: true, relation: 'TicketPriority', filter: @bulk, translate: true, nulloption: true, default: '', class: 'span2', item_class: 'pull-left' },
      { name: 'group_id',     display: 'Group',    tag: 'select',   multiple: false, null: true, relation: 'Group', filter: @bulk, nulloption: true, class: 'span2', item_class: 'pull-left'  },
      { name: 'owner_id',     display: 'Owner',    tag: 'select',   multiple: false, null: true, relation: 'User', filter: @bulk, nulloption: true, class: 'span2', item_class: 'pull-left' },
    ]

    # render init page
    html = $( App.view('agent_ticket_view/bulk')() )
    new App.ControllerForm(
      el: html.find('#form-ticket-bulk'),
      model: {
        configure_attributes: @configure_attributes_ticket,
        className:            'create',
      },
      form_data: @bulk,
    )
#    html.delegate('.bulk-action-form', 'submit', (e) =>
    html.bind('submit', (e) =>
      e.preventDefault()
      @bulk_submit(e)
    )
    return html

  bulkGetSelected: ->
    @ticketIDs = []
    @el.find('.table-overview').find('[name="bulk"]:checked').each( (index, element) =>
      ticket_id = $(element).val()
      @ticketIDs.push ticket_id
    )
    @ticketIDs

  bulkSetSelected: (ticketIDs) ->
    @el.find('.table-overview').find('[name="bulk"]').each( (index, element) =>
      ticket_id = $(element).val()
      for ticket_id_selected in ticketIDs
        if ticket_id_selected is ticket_id
          $(element).attr( 'checked', true )
    )

  bulk_submit: (e) =>
    @bulk_count = @el.find('.table-overview').find('[name="bulk"]:checked').length
    @bulk_count_index = 0
    @el.find('.table-overview').find('[name="bulk"]:checked').each( (index, element) =>
      @log 'notice', '@bulk_count_index', @bulk_count, @bulk_count_index
      ticket_id = $(element).val()
      ticket = App.Ticket.find(ticket_id)
      params = @formParam(e.target)

      # update ticket
      ticket_update = {}
      for item of params
        if params[item] != ''
          ticket_update[item] = params[item]

#      @log 'notice', 'update', params, ticket_update, ticket

      ticket.load(ticket_update)
      ticket.save(
        done: (r) =>
          @bulk_count_index++

          # refresh view after all tickets are proceeded
          if @bulk_count_index == @bulk_count

            # rebuild navbar with updated ticket count of overviews
            App.WebSocket.send( event: 'navupdate_ticket_overview' )

            # fetch overview data again
            @fetch()
      )
    )
    @el.find('.table-overview').find('[name="bulk"]:checked').prop('checked', false)
    App.Event.trigger 'notify', {
      type: 'success'
      msg: App.i18n.translateContent('Bulk-Action executed!')
    }

  zoom: (e) =>
    e.preventDefault()
    id = $(e.target).parents('[data-id]').data('id')
    position = $(e.target).parents('[data-position]').data('position')

    # set last overview
    @Config.set('LastOverview', @view )
    @Config.set('LastOverviewPosition', position )
    @Config.set('LastOverviewTotal', @tickets_count )

    @navigate 'ticket/zoom/' + id + '/nav/true'

  settings: (e) =>
    e.preventDefault()
    new App.OverviewSettings(
      overview_id: @overview.id
      view_mode:   @view_mode
    )

class App.OverviewSettings extends App.ControllerModal
  constructor: ->
    super
    @overview = App.Overview.find(@overview_id)
    @render()

  render: ->

    @html App.view('dashboard/ticket_settings')(
      overview: @overview,
    )
    @configure_attributes_article = []
    if @view_mode is 'd'
      @configure_attributes_article.push({
        name:     'view::per_page',
        display:  'Items per page',
        tag:      'select',
        multiple: false,
        null:     false,
        default: @overview.view.per_page
        options: {
          5: ' 5'
          10: '10'
          15: '15'
          20: '20'
          25: '25'
        },
        class: 'medium',
      })
    @configure_attributes_article.push({
      name:    "view::#{@view_mode}"
      display: 'Attributes'
      tag:     'checkbox'
      default: @overview.view[@view_mode]
      null:    false
      translate: true
      options: [
        {
          value:  'number'
          name:   'Number'
        },
        {
          value:  'title'
          name:   'Title'
        },
        {
          value:  'customer'
          name:   'Customer'
        },
        {
          value:  'organization'
          name:   'Organization'
        },
        {
          value:  'state'
          name:   'State'
        },
        {
          value:  'priority'
          name:   'Priority'
        },
        {
          value:  'group'
          name:   'Group'
        },
        {
          value:  'owner'
          name:   'Owner'
        },
        {
          value:  'created_at'
          name:   'Age'
        },
        {
          value:  'last_contact'
          name:   'Last Contact'
        },
        {
          value:  'last_contact_agent'
          name:   'Last Contact Agent'
        },
        {
          value:  'last_contact_customer'
          name:   'Last Contact Customer'
        },
        {
          value:  'first_response'
          name:   'First Response'
        },
        {
          value:  'close_time'
          name:   'Close Time'
        },
        {
          value:  'escalation_time'
          name:   'Escalation in'
        },
        {
          value:  'article_count'
          name:   'Article Count'
        },
      ]
      class:      'medium'
    },
    {
      name:    'order::by'
      display: 'Order'
      tag:     'select'
      default: @overview.order.by
      null:    false
      translate: true
      options:
        number:                 'Number'
        title:                  'Title'
        customer:               'Customer'
        organization:           'Organization'
        state:                  'State'
        priority:               'Priority'
        group:                  'Group'
        owner:                  'Owner'
        created_at:             'Age'
        last_contact:           'Last Contact'
        last_contact_agent:     'Last Contact Agent'
        last_contact_customer:  'Last Contact Customer'
        first_response:         'First Response'
        close_time:             'Close Time'
        escalation_time:        'Escalation in'
        article_count:          'Article Count'
      class:   'medium'
    },
    {
      name:    'order::direction'
      display: 'Direction'
      tag:     'select'
      default: @overview.order.direction
      null:    false
      translate: true
      options:
        ASC:   'up'
        DESC:  'down'
      class:   'medium'
    },
    {
      name:    'group_by'
      display: 'Group by'
      tag:     'select'
      default: @overview.group_by
      null:    true
      nulloption: true
      translate:  true
      options:
        customer:       'Customer'
        organization:   'Organization'
        state:          'State'
        priority:       'Priority'
        group:          'Group'
        owner:          'Owner'
      class:   'medium'
    })

    new App.ControllerForm(
      el:        @el.find('#form-setting')
      model:     { configure_attributes: @configure_attributes_article }
      autofocus: false
    )

    @modalShow()

  submit: (e) =>
    e.preventDefault()
    params = @formParam(e.target)

    # check if refetch is needed
    @reload_needed = 0
    if @overview.order.by isnt params.order.by
      @overview.order.by = params.order.by
      @reload_needed = 1

    if @overview.order.direction isnt params.order.direction
      @overview.order.direction = params.order.direction
      @reload_needed = 1

    for key, value of params.view
      @overview.view[key] = value

    @overview.group_by = params.group_by

    @overview.save(
      done: =>
        if @reload_needed
          @overview.trigger('local:refetch')
        else
          @overview.trigger('local:rerender')
    )
    @modalHide()

class Navbar extends App.Controller
  constructor: ->
    super

    # rebuild ticket overview data
    @bind 'navupdate_ticket_overview', (data) =>
      if !_.isEmpty(data)
        App.Store.write( 'navupdate_ticket_overview', data )
        @render(data)

    cache = App.Store.get( 'navupdate_ticket_overview' )
    if cache
      @render( cache )
    else
      @render( [] )

      # init fetch via ajax, all other updates on time via websockets
      @ajax(
        id:    'ticket_overviews',
        type:  'GET',
        url:   @apiPath + '/ticket_overviews',
        processData: true,
        success: (data) =>
          App.Store.write( 'navupdate_ticket_overview', data )
          @render(data)
        )

  render: (dataOrig) ->

    data = _.clone(dataOrig)

    # add new views
    for item in data
      item.target = '#ticket/view/' + item.link
      if item.link is @view
        item.active = true
      else
        item.active = false

    @html App.view('agent_ticket_view/navbar')(
      items: data
    )


class Router extends App.Controller
  constructor: ->
    super

    # set new key
    @key = 'ticket_overview_' + @view

    # get data
    cache = App.Store.get( @key )
    if cache
      @tickets_count = cache.tickets_count
      @ticket_ids    = cache.ticket_ids
      @redirect()
    else
      @ajax(
        type:       'GET'
        url:        @apiPath + '/ticket_overviews'
        data:
          view:      @view
          array:     true
        processData: true
        success:     @load
      )

  load: (data) =>
    @ticket_ids    = data.ticket_ids
    @tickets_count = data.tickets_count
#    App.Store.write( data )
    @redirect()

  redirect: =>
    @Config.set('LastOverview', @view )
    @position = parseInt( @position )
    @Config.set('LastOverviewPosition', @position )
    @Config.set('LastOverviewTotal', @tickets_count )

    # redirect
    if @direction == 'next'
      if @ticket_ids[ @position ] && @ticket_ids[ @position ]
        position = @position + 1
        @Config.set( 'LastOverviewPosition', position )
        @navigate 'ticket/zoom/' + @ticket_ids[ @position ] + '/nav/true'
      else
        @navigate 'ticket/zoom/' + @ticket_ids[ @position - 1 ] + '/nav/true'
    else
      if @ticket_ids[ @position - 2 ] && @ticket_ids[ @position - 2 ] + '/nav/true'
        position = @position - 1
        @Config.set( 'LastOverviewPosition', position )
        @navigate 'ticket/zoom/' + @ticket_ids[ @position - 2 ] + '/nav/true'
      else
        @navigate 'ticket/zoom/' + @ticket_ids[ @position - 1 ] + '/nav/true'

App.Config.set( 'ticket/view', Index, 'Routes' )
App.Config.set( 'ticket/view/:view', Index, 'Routes' )
#App.Config.set( 'ticket/view/:view/:position/:direction', Router, 'Routes' )

App.Config.set( 'TicketOverview', { prio: 1000, parent: '', name: 'Overviews', target: '#ticket/view', role: ['Agent', 'Customer'], class: 'overviews' }, 'NavBar' )
