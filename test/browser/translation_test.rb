# encoding: utf-8
require 'browser_test_helper'

class TranslationTest < TestCase
  def test_preferences
    @browser = browser_instance
    login(
      username: 'master@example.com',
      password: 'test',
      url: browser_url,
    )
    tasks_close_all()

    click(css: 'a[href="#current_user"]')
    click(css: 'a[href="#profile"]')
    click(css: 'a[href="#profile/language"]')
    select(
      css: '.language_item select[name="locale"]',
      value: 'English (United States)',
    )
    click(css: '.content button[type="submit"]')
    sleep 2
    watch_for(
      css: 'body',
      value: 'Language',
    )

    click(css: 'a[href="#manage"]')
    click(css: 'a[href="#system/translation"]')

    watch_for(
      css: '#content',
      value: 'English is the source language, so we have nothing to translate',
    )

    click(css: 'a[href="#current_user"]')
    click(css: 'a[href="#profile"]')
    click(css: 'a[href="#profile/language"]')
    select(
      css: '.language_item select[name="locale"]',
      value: 'Deutsch',
    )
    click(css: '.content button[type="submit"]')
    watch_for(
      css: 'body',
      value: 'Sprache',
    )

    click(css: 'a[href="#manage"]')
    click(css: 'a[href="#system/translation"]')

    set(
      css: '#content input.js-Item[data-source="Translations"]',
      value: 'Übersetzung2',
    )
    sleep 5 # wait until nofify is gone
    click(css: '#global-search')
    sleep 4 # wait till rerender

    click(css: 'a[href="#dashboard"]')
    sleep 2 # wait till nav is rendered

    click(css: 'a[href="#manage"]')
    click(css: 'a[href="#system/translation"]')

    match(
      css: '#content .sidebar',
      value: 'Übersetzung2',
    )
    match(
      css: '#content input.js-Item[data-source="Translations"]',
      value: 'Übersetzung2',
    )

    execute(
      js: "$('.js-Item[data-source=Translations]').parents('tr').find('.js-Reset:visible').click()",
    )
    sleep 5

    match(
      css: '#content .sidebar',
      value: 'Übersetzung2',
    )
    match_not(
      css: '#content input.js-Item[data-source="Translations"]',
      value: 'Übersetzung2',
    )

    click(css: 'a[href="#dashboard"]')
    sleep 4 # wait till rerender

    click(css: 'a[href="#manage"]')
    click(css: 'a[href="#system/translation"]')
    sleep 2

    match_not(
      css: '#content .sidebar',
      value: 'Übersetzung2',
    )
    match_not(
      css: '#content input.js-Item[data-source="Translations"]',
      value: 'Übersetzung2',
    )
    match_not(
      css: '#content .sidebar',
      value: 'Übersetzung2',
    )

    @browser.action.key_down(:control)
      .key_down(:alt)
      .send_keys('t')
      .key_up(:alt)
      .key_up(:control)
      .perform

    watch_for(
      css: 'span.translation[title="Overviews"]',
      value: 'Übersichten',
    )
    set(
      css: 'span.translation[title="Overviews"]',
      value: 'Übersichten123',
    )
    sleep 1
    click(css: 'a[href="#dashboard"]')
    sleep 5

    @browser.action.key_down(:control)
      .key_down(:alt)
      .send_keys('t')
      .key_up(:alt)
      .key_up(:control)
      .perform

    sleep 5
    exists_not(
      css: 'span.translation[title="Overviews"]',
    )
    match(
      css: '.js-menu',
      value: 'Übersichten123',
    )

    reload()
    exists_not(
      css: 'span.translation[title="Overviews"]',
    )
    match(
      css: '.js-menu',
      value: 'Übersichten123',
    )

    click(css: 'a[href="#manage"]')
    click(css: 'a[href="#system/translation"]')
    sleep 4

    match(
      css: '#content input.js-Item[data-source="Overviews"]',
      value: 'Übersichten123',
    )

    execute(
      js: "$('.js-Item[data-source=Overviews]').parents('tr').find('.js-Reset:visible').click()",
    )
    sleep 5

    click(css: 'a[href="#dashboard"]')
    sleep 5

    match_not(
      css: '.js-menu',
      value: 'Übersichten123',
    )
    match(
      css: '.js-menu',
      value: 'Übersichten',
    )

    click(css: 'a[href="#current_user"]')
    click(css: 'a[href="#profile"]')
    click(css: 'a[href="#profile/language"]')
    select(
      css: '.language_item select[name="locale"]',
      value: 'English (United States)',
    )
    click(css: '.content button[type="submit"]')
    sleep 2
    watch_for(
      css: 'body',
      value: 'Language',
    )
    sleep 5

    @browser.action.key_down(:control)
      .key_down(:alt)
      .send_keys('t')
      .key_up(:alt)
      .key_up(:control)
      .perform

    watch_for(
      css: 'span.translation[title="Overviews"]',
      value: 'Overviews',
    )
    set(
      css: 'span.translation[title="Overviews"]',
      value: 'Overviews123',
    )
    sleep 1
    click(css: 'a[href="#dashboard"]')
    sleep 5

    @browser.action.key_down(:control)
      .key_down(:alt)
      .send_keys('t')
      .key_up(:alt)
      .key_up(:control)
      .perform

    sleep 5
    exists_not(
      css: 'span.translation[title="Overviews"]',
    )
    match(
      css: '.js-menu',
      value: 'Overviews123',
    )

    click(css: 'a[href="#manage"]')
    click(css: 'a[href="#system/translation"]')
    sleep 4

    match(
      css: '#content input.js-Item[data-source="Overviews"]',
      value: 'Overviews123',
    )
    match_not(
      css: '#content',
      value: 'English is the source language, so we have nothing to translate',
    )

    execute(
      js: "$('.js-Item[data-source=Overviews]').parents('tr').find('.js-Reset:visible').click()",
    )

    watch_for(
      css: '#content',
      value: 'English is the source language, so we have nothing to translate',
    )

  end
end