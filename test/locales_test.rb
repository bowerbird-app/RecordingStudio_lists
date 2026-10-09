# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "test_helper"
require_relative "dummy/config/environment"
require "yaml"

class LocalesTest < ActiveSupport::TestCase
  INDEX_KEYS = {
    "title" => "Lists",
    "home" => "Home",
    "new_button" => "List",
    "empty" => "No lists yet."
  }.freeze

  NEW_KEYS = {
    "title" => "New list",
    "back" => "Lists",
    "name" => "Name",
    "description" => "Description",
    "create" => "Create list"
  }.freeze

  SHOW_KEYS = {
    "back" => "Lists",
    "empty" => "Nothing here yet.",
    "missing" => "Missing",
    "remove" => "Remove",
    "delete" => "Delete list",
    "delete_confirm" => "Delete this list?"
  }.freeze

  ADD_TO_LIST_KEYS = {
    "trigger" => "Add to list",
    "new_list" => "List",
    "name" => "Name",
    "save" => "Save"
  }.freeze

  test "engine ships only english locale files" do
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  test "rails i18n load path includes the gem english locale file" do
    locale_path = File.join(engine_locales_dir, "en.yml")

    assert_includes I18n.load_path.map { |path| File.expand_path(path) }, File.expand_path(locale_path)
  end

  test "english lists keys resolve without missing translations" do
    I18n.with_locale(:en) do
      INDEX_KEYS.each { |key, english| assert_key("recording_studio.lists.index.#{key}", english) }
      NEW_KEYS.each { |key, english| assert_key("recording_studio.lists.new.#{key}", english) }
      SHOW_KEYS.each { |key, english| assert_key("recording_studio.lists.show.#{key}", english) }
      ADD_TO_LIST_KEYS.each { |key, english| assert_key("recording_studio.lists.add_to_list.#{key}", english) }

      assert_equal "0 items", I18n.t("recording_studio.lists.show.item_count", count: 0)
      assert_equal "1 item", I18n.t("recording_studio.lists.show.item_count", count: 1)
      assert_equal "2 items", I18n.t("recording_studio.lists.show.item_count", count: 2)
    end
  end

  test "en.yml nests keys under recording_studio.lists" do
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("lists")

    assert_equal INDEX_KEYS, tree.fetch("index").transform_keys(&:to_s)
    assert_equal NEW_KEYS, tree.fetch("new").transform_keys(&:to_s)
    assert_equal ADD_TO_LIST_KEYS, tree.fetch("add_to_list").transform_keys(&:to_s)

    show = tree.fetch("show").transform_keys(&:to_s)
    SHOW_KEYS.each do |key, english|
      assert_equal english, show.fetch(key)
    end
    assert_equal({ "one" => "%{count} item", "other" => "%{count} items" }, show.fetch("item_count").transform_keys(&:to_s))
  end

  test "gem does not ship a legacy recording_studio_lists locale namespace" do
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")

    refute tree.key?("recording_studio_lists")
    refute Dir[File.join(engine_locales_dir, "*recording_studio_lists*")].any?
  end

  private

  def assert_key(full_key, english)
    translation = I18n.t(full_key, default: nil)

    assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
    assert_equal english, I18n.t(full_key, raise: true)
  end

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end
end
