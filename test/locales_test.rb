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

  FLASH_KEYS = {
    "created" => "List created.",
    "added" => "Added.",
    "removed" => "Removed.",
    "deleted" => "List deleted."
  }.freeze

  ERROR_KEYS = {
    "blank_name" => "Name can't be blank.",
    "invalid_list" => "That list is missing.",
    "missing_target" => "Pick something to add.",
    "different_root" => "That lives somewhere else.",
    "self_target" => "A list can't contain itself.",
    "list_item_target" => "That can't go on a list.",
    "parent_not_allowed" => "Lists can't be created here.",
    "choose_place" => "Choose a place for this list first."
  }.freeze

  JS_KEYS = {
    "blank_name" => "Name can't be blank.",
    "save_failed" => "That didn't save. Try again."
  }.freeze

  test "engine ships only english locale files" do
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  test "rails i18n load path includes the gem english locale file" do
    locale_path = File.join(engine_locales_dir, "en.yml")

    assert_includes I18n.load_path.map { |path| File.expand_path(path) }, File.expand_path(locale_path)
  end

  test "lib sources do not append i18n load path" do
    lib_root = File.expand_path("../lib", __dir__)
    Dir[File.join(lib_root, "**", "*.rb")].each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path", "#{path} must not touch i18n.load_path"
      refute_includes source, "I18n.load_path", "#{path} must not touch I18n.load_path"
    end
  end

  test "english lists keys resolve without missing translations" do
    I18n.with_locale(:en) do
      INDEX_KEYS.each do |key, english|
        # dummy always-loads a host override for index.home (boot-order guard)
        next if key == "home"

        assert_key("recording_studio.lists.index.#{key}", english)
      end
      assert_equal "HOST Home", I18n.t("recording_studio.lists.index.home", raise: true)
      NEW_KEYS.each { |key, english| assert_key("recording_studio.lists.new.#{key}", english) }
      SHOW_KEYS.each { |key, english| assert_key("recording_studio.lists.show.#{key}", english) }
      ADD_TO_LIST_KEYS.each { |key, english| assert_key("recording_studio.lists.add_to_list.#{key}", english) }
      FLASH_KEYS.each { |key, english| assert_key("recording_studio.lists.flashes.#{key}", english) }
      ERROR_KEYS.each { |key, english| assert_key("recording_studio.lists.errors.#{key}", english) }
      JS_KEYS.each { |key, english| assert_key("recording_studio.lists.js.#{key}", english) }

      assert_equal "0 items", I18n.t("recording_studio.lists.show.item_count", count: 0)
      assert_equal "1 item", I18n.t("recording_studio.lists.show.item_count", count: 1)
      assert_equal "2 items", I18n.t("recording_studio.lists.show.item_count", count: 2)
      assert_equal "List", I18n.t("recording_studio.lists.recordables.list.label", count: 1)
      assert_equal "Lists", I18n.t("recording_studio.lists.recordables.list.label", count: 2)
      assert_equal "List item", I18n.t("recording_studio.lists.recordables.list_item.label", count: 1)
      assert_equal "List items", I18n.t("recording_studio.lists.recordables.list_item.label", count: 2)
    end
  end

  test "en.yml nests keys under recording_studio.lists" do
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("lists")

    assert_equal INDEX_KEYS, tree.fetch("index").transform_keys(&:to_s)
    assert_equal NEW_KEYS, tree.fetch("new").transform_keys(&:to_s)
    assert_equal ADD_TO_LIST_KEYS, tree.fetch("add_to_list").transform_keys(&:to_s)
    assert_equal FLASH_KEYS, tree.fetch("flashes").transform_keys(&:to_s)
    assert_equal ERROR_KEYS, tree.fetch("errors").transform_keys(&:to_s)
    assert_equal JS_KEYS, tree.fetch("js").transform_keys(&:to_s)

    show = tree.fetch("show").transform_keys(&:to_s)
    SHOW_KEYS.each do |key, english|
      assert_equal english, show.fetch(key)
    end
    expected_counts = {
      "one" => "%{count} item", # rubocop:disable Style/FormatStringToken -- I18n pluralization syntax
      "other" => "%{count} items" # rubocop:disable Style/FormatStringToken -- I18n pluralization syntax
    }
    assert_equal expected_counts, show.fetch("item_count").transform_keys(&:to_s)

    list_labels = tree.fetch("recordables").fetch("list").fetch("label").transform_keys(&:to_s)
    assert_equal({ "one" => "List", "other" => "Lists" }, list_labels)
    item_labels = tree.fetch("recordables").fetch("list_item").fetch("label").transform_keys(&:to_s)
    assert_equal({ "one" => "List item", "other" => "List items" }, item_labels)
  end

  test "gem does not ship a legacy recording_studio_lists locale namespace" do
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")

    refute tree.key?("recording_studio_lists")
    refute Dir[File.join(engine_locales_dir, "*recording_studio_lists*")].any?
  end

  test "error class english defaults stay byte-identical to main" do
    assert_equal "Name can't be blank.", RecordingStudio::Lists::BlankName.new.message
    assert_equal "That list is missing.", RecordingStudio::Lists::InvalidList.new.message
    assert_equal "Pick something to add.", RecordingStudio::Lists::MissingTarget.new.message
    assert_equal "That lives somewhere else.", RecordingStudio::Lists::DifferentRoot.new.message
    assert_equal "A list can't contain itself.", RecordingStudio::Lists::SelfTarget.new.message
    assert_equal "That can't go on a list.", RecordingStudio::Lists::ListItemTarget.new.message
    assert_equal "Lists can't be created here.", RecordingStudio::Lists::ParentNotAllowed.new.message
    assert_equal(
      "Choose a place for this list first.",
      RecordingStudio::Lists::ParentNotAllowed.new("Choose a place for this list first.").message
    )
  end

  test "error class messages stay english when the locale is not english" do
    I18n.available_locales = Array(I18n.available_locales) | %i[en fr]
    I18n.backend.store_translations(
      :fr,
      recording_studio: {
        lists: {
          errors: {
            blank_name: "Le nom ne peut pas être vide.",
            different_root: "Ça vit ailleurs.",
            choose_place: "Choisissez d'abord un endroit pour cette liste."
          }
        }
      }
    )

    I18n.with_locale(:fr) do
      assert_equal "Name can't be blank.", RecordingStudio::Lists::BlankName.new.message
      assert_equal "That lives somewhere else.", RecordingStudio::Lists::DifferentRoot.new.message
      assert_equal(
        "Choose a place for this list first.",
        RecordingStudio::Lists::ParentNotAllowed.new("Choose a place for this list first.").message
      )
      assert_equal(
        "Le nom ne peut pas être vide.",
        RecordingStudioLists::Copy.t("errors.blank_name")
      )
      assert_equal(
        "Le nom ne peut pas être vide.",
        RecordingStudio.t("recording_studio.lists.errors.blank_name")
      )
    end
  end

  test "engine registers shipped english before recording_studio load" do
    names = RecordingStudioLists::Engine.initializers.map(&:name)
    assert_includes names, "recording_studio_lists.register_shipped_english"

    initializer = RecordingStudioLists::Engine.initializers.find do |entry|
      entry.name == "recording_studio_lists.register_shipped_english"
    end
    assert_equal "recording_studio.load_shipped_english", initializer.before
  end

  private

  def assert_key(full_key, english)
    translation = I18n.t(full_key, default: nil)

    assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
    assert_equal english, I18n.t(full_key, raise: true)
    assert_equal english, RecordingStudio.t(full_key)
  end

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end
end
