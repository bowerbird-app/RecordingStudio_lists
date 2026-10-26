# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "test_helper"
require_relative "dummy/config/environment"
require "yaml"

# Behavioral coverage for RecordingStudio.t against this gem's registered
# shipped English. Pointed at the base helper (no gem-local Translation).
class TranslationTest < ActiveSupport::TestCase
  GEM_KEYS = {
    "recording_studio.lists.index.title" => "Lists",
    "recording_studio.lists.index.empty" => "No lists yet.",
    "recording_studio.lists.index.edit" => "Edit list",
    "recording_studio.lists.new.title" => "New list",
    "recording_studio.lists.edit.title" => "Edit list",
    "recording_studio.lists.edit.save" => "Save",
    "recording_studio.lists.show.empty" => "Nothing here yet.",
    "recording_studio.lists.add_to_list.trigger" => "Add to list",
    "recording_studio.lists.add_to_list.icon_only" => "Add to list",
    "recording_studio.lists.flashes.created" => "List created.",
    "recording_studio.lists.flashes.updated" => "List updated.",
    "recording_studio.lists.errors.blank_name" => "Name can't be blank.",
    "recording_studio.lists.js.save_failed" => "That didn't save. Try again."
  }.freeze

  setup do
    @previous_locales = I18n.available_locales
    I18n.available_locales = (@previous_locales + %i[en fr de xx]).uniq
  end

  teardown do
    I18n.locale = I18n.default_locale
    I18n.available_locales = @previous_locales if @previous_locales
    I18n.reload!
  end

  test "english locale resolves every sample gem key from RecordingStudio.t" do
    I18n.with_locale(:en) do
      GEM_KEYS.each do |key, english|
        next if key == "recording_studio.lists.index.home"

        assert_equal english, RecordingStudio.t(key)
        assert_equal english, RecordingStudioLists::Copy.t(key.delete_prefix("recording_studio.lists."))
      end
    end
  end

  test "engine registers lists en.yml into merged shipped english table" do
    # Assert boot registration only — do not call the initializer block here.
    en_path = File.expand_path("../config/locales/en.yml", __dir__)
    paths = RecordingStudio::Translation.send(:registered_shipped_english_paths)
    assert_includes paths, File.expand_path(en_path)

    table = RecordingStudio::Translation.shipped_english
    en_yml = YAML.safe_load_file(en_path, aliases: true)
                 .fetch("en").fetch("recording_studio").fetch("lists")
    expected = flatten_locale_keys(en_yml, %w[recording_studio lists])

    expected.each do |key, english|
      assert_equal english, table.fetch(key), "#{key} must be in merged shipped english"
    end
    assert_predicate table, :frozen?
    assert_same table, RecordingStudio::Translation.shipped_english,
                "shipped english must be reused across calls"
  end

  test "deleted loaded english falls back to registered gem en.yml text" do
    GEM_KEYS.each_key do |key|
      delete_loaded_translation!(:en, key)
      delete_loaded_translation!(:fr, key)
    end

    GEM_KEYS.each do |key, english|
      refute I18n.exists?(key, :en), "#{key} must be absent from loaded :en"
      I18n.with_locale(:en) do
        assert_equal english, RecordingStudio.t(key)
        refute_match(/translation missing/i, RecordingStudio.t(key))
      end
      I18n.with_locale(:fr) do
        assert_equal english, RecordingStudio.t(key)
        refute_match(/translation missing/i, RecordingStudio.t(key))
      end
    end
  ensure
    I18n.reload!
  end

  test "missing locale falls back to loaded english" do
    I18n.with_locale(:de) do
      GEM_KEYS.each do |key, english|
        refute I18n.exists?(key, :de), "#{key} must be absent in :de for this test"
        assert_equal english, RecordingStudio.t(key)
        refute_match(/translation missing/i, RecordingStudio.t(key))
      end
    end
  end

  test "does not raise for missing locale when callers use raise-on-missing style lookups" do
    key = "recording_studio.lists.index.title"
    I18n.with_locale(:de) do
      assert_raises(I18n::MissingTranslationData) do
        I18n.t(key, locale: :de, raise: true)
      end

      assert_equal "Lists", RecordingStudio.t(key)
    end
  end

  test "parity matrix non-gem keys match I18n.t" do
    # I18n interpolation tokens use %{name}; RuboCop prefers %<name>s for Kernel#sprintf.
    # rubocop:disable Style/FormatStringToken
    I18n.backend.store_translations(:en, {
                                      probe: {
                                        greet: "Hi %{name}",
                                        empty: "",
                                        nil_value: nil,
                                        nest: { a: "A" },
                                        html_key_html: "<b>x</b>",
                                        items: { one: "one item", other: "%{count} items" }
                                      }
                                    })
    I18n.backend.store_translations(:de, { probe: { greet: "Hallo %{name}" } })
    # rubocop:enable Style/FormatStringToken

    I18n.with_locale(:de) do
      assert_parity("probe.greet", name: "M")
      assert_parity("probe.missing")
      assert_parity("probe.missing", default: "D")
      assert_parity("probe.empty")
      assert_parity("probe.nil_value")
      assert_parity("probe.nest")
      assert_parity("probe.items", count: 1)
      assert_parity("probe.items", count: 5)
      assert_parity(:"probe.greet", name: "M")
      assert_parity(%w[probe.missing probe.greet], name: "M")
      assert_parity("greet", scope: "probe", name: "M")
      assert_raise_parity("probe.missing", raise: true)
      assert_parity("probe.greet", locale: :en, name: "M")
      assert_parity("probe.html_key_html")
    end
  end

  test "parity matrix gem keys cover missing default raise nil empty hash and related options" do
    key = "recording_studio.lists.index.title"
    missing = "recording_studio.lists.index.missing_key_for_parity"

    # rubocop:disable Style/FormatStringToken -- I18n interpolation syntax
    I18n.backend.store_translations(:en, {
                                      recording_studio: {
                                        lists: {
                                          index: {
                                            nil_value: nil,
                                            empty_value: "",
                                            nest: { a: "A" },
                                            html_key_html: "<i>g</i>",
                                            items: { one: "one", other: "%{count} many" },
                                            greet: "Hi %{name}"
                                          }
                                        }
                                      }
                                    })
    # rubocop:enable Style/FormatStringToken

    I18n.with_locale(:en) do
      assert_equal I18n.t(key), RecordingStudio.t(key)
      assert_equal "Lists", RecordingStudio.t(key, default: "Ignored when present")
    end

    I18n.with_locale(:de) do
      assert_equal "Lists", RecordingStudio.t(key)
      assert_match(/translation missing/i, I18n.t(key))

      assert_parity(missing)
      assert_parity(missing, default: "D")
      assert_raise_parity(missing, raise: true)

      I18n.backend.store_translations(:de, {
                                        recording_studio: { lists: { index: { title: "DE Listen" } } }
                                      })
      assert_equal "DE Listen", RecordingStudio.t(key)
      assert_equal I18n.t(key), RecordingStudio.t(key)

      assert_parity("recording_studio.lists.index.nil_value")
      assert_equal "", RecordingStudio.t("recording_studio.lists.index.empty_value")
      assert_match(/translation missing/i, I18n.t("recording_studio.lists.index.empty_value"))

      assert_equal(
        I18n.t("recording_studio.lists.index.nest", locale: :en),
        RecordingStudio.t("recording_studio.lists.index.nest")
      )
      assert_equal(
        I18n.t("recording_studio.lists.index.items", locale: :en, count: 1),
        RecordingStudio.t("recording_studio.lists.index.items", count: 1)
      )
      assert_equal(
        I18n.t("recording_studio.lists.index.greet", locale: :en, name: "M"),
        RecordingStudio.t("recording_studio.lists.index.greet", name: "M")
      )

      assert_equal "DE Listen", RecordingStudio.t(:"recording_studio.lists.index.title")
      assert_equal(
        ["DE Listen", "No lists yet."],
        RecordingStudio.t(%w[
                            recording_studio.lists.index.title
                            recording_studio.lists.index.empty
                          ])
      )
      assert_equal "DE Listen", RecordingStudio.t(:title, scope: "recording_studio.lists.index")
      assert_equal(
        "No lists yet.",
        RecordingStudio.t(:empty, scope: "recording_studio.lists.index")
      )

      html = RecordingStudio.t("recording_studio.lists.index.html_key_html")
      assert_equal "<i>g</i>", html
      assert_predicate html, :html_safe?

      assert_equal "D", RecordingStudio.t(missing, default: "D")

      I18n.backend.store_translations(:en, {
                                        recording_studio: {
                                          lists: { index: { missing_key_for_parity: "EN" } }
                                        }
                                      })
      assert_equal "EN", RecordingStudio.t(missing, default: "D")

      error = assert_raises(I18n::MissingTranslationData) do
        RecordingStudio.t("recording_studio.lists.index.totally_absent", raise: true)
      end
      assert_match(/Translation missing: de\.recording_studio/, error.message)

      assert_equal "Lists", RecordingStudio.t(key, locale: :en)
    end
  end

  test "fallback order prefers loaded english then caller default over shipped table" do
    key = "recording_studio.lists.index.title"

    write_loaded_translation!(:en, key, "HOST EN Lists")
    I18n.with_locale(:de) do
      refute I18n.exists?(key, :de)
      assert_equal "HOST EN Lists", RecordingStudio.t(key),
                   "host :en override must win over the gem-shipped table"
    end

    delete_loaded_translation!(:en, key)
    delete_loaded_translation!(:fr, key)
    %i[en fr de].each do |locale|
      I18n.with_locale(locale) do
        assert_equal "CALLER", RecordingStudio.t(key, default: "CALLER"),
                     "caller default: must come before the gem-shipped table in #{locale}"
        assert_equal "Lists", RecordingStudio.t(key),
                     "registered gem table is used last and matches en.yml in #{locale}"
      end
    end
  ensure
    I18n.reload!
  end

  test "html gem keys escape unsafe interpolation like view t" do
    # rubocop:disable Style/FormatStringToken -- I18n interpolation syntax
    I18n.backend.store_translations(:en, {
                                      recording_studio: {
                                        lists: {
                                          probe: {
                                            hi_html: "<b>Hi %{name}</b>",
                                            greet: "Hi %{name}",
                                            items_html: {
                                              one: "<i>1 x</i>",
                                              other: "<i>%{count} xs</i>"
                                            }
                                          }
                                        }
                                      }
                                    })
    # rubocop:enable Style/FormatStringToken
    view = ActionController::Base.helpers

    I18n.with_locale(:en) do
      value = RecordingStudio.t("recording_studio.lists.probe.hi_html", name: "<script>")
      assert_equal "<b>Hi &lt;script&gt;</b>", value
      assert_predicate value, :html_safe?
      assert_equal view.t("recording_studio.lists.probe.hi_html", name: "<script>"), value

      plain = RecordingStudio.t("recording_studio.lists.probe.greet", name: "<s>")
      assert_equal "Hi <s>", plain
      refute_predicate plain, :html_safe?
      assert_equal view.t("recording_studio.lists.probe.greet", name: "<s>"), plain

      safe_arg = "<u>ok</u>".html_safe
      with_safe = RecordingStudio.t("recording_studio.lists.probe.hi_html", name: safe_arg)
      assert_equal "<b>Hi <u>ok</u></b>", with_safe
      assert_equal view.t("recording_studio.lists.probe.hi_html", name: safe_arg), with_safe

      plural = RecordingStudio.t("recording_studio.lists.probe.items_html", count: 2)
      assert_equal "<i>2 xs</i>", plural
      assert_predicate plural, :html_safe?
      assert_equal view.t("recording_studio.lists.probe.items_html", count: 2), plural

      singular = RecordingStudio.t("recording_studio.lists.probe.items_html", count: 1)
      assert_equal "<i>1 x</i>", singular
      assert_predicate singular, :html_safe?
      assert_equal view.t("recording_studio.lists.probe.items_html", count: 1), singular

      missing_html = "recording_studio.lists.probe.missing_key_html"
      reserved = RecordingStudio.t(missing_html, default: "<b>ok</b>")
      assert_equal "<b>ok</b>", reserved
      refute_predicate reserved, :html_safe?
      assert_equal view.t(missing_html, default: "<b>ok</b>"), reserved
    end
  end

  test "shipped english table is present after boot with lists keys" do
    refute_nil RecordingStudio::Translation.instance_variable_get(:@shipped_english),
               "engine initializer / to_prepare must eager-load shipped english before any call"
    assert_includes RecordingStudioLists::Engine.initializers.map(&:name),
                    "recording_studio_lists.register_shipped_english"
    table = RecordingStudio::Translation.shipped_english
    refute_empty table
    assert_equal "Lists", table.fetch("recording_studio.lists.index.title")
  end

  test "shipped english table becomes a new object after reload reset" do
    before = RecordingStudio::Translation.shipped_english
    begin
      Rails.application.reloader.reload!
    rescue StandardError
      # Dummy host initializers may re-register resources on full reload.
    end
    after = RecordingStudio::Translation.shipped_english

    refute_same before, after
    assert_equal before.fetch("recording_studio.lists.index.title"),
                 after.fetch("recording_studio.lists.index.title")
    assert_predicate after, :frozen?
  end

  test "missing registered en.yml path contributes empty hash without raising" do
    missing_path = File.expand_path("../tmp/missing_lists_en_#{Process.pid}.yml", __dir__)
    refute File.exist?(missing_path)

    RecordingStudio::Translation.register_shipped_english(missing_path)
    table = RecordingStudio::Translation.shipped_english
    assert_predicate table, :frozen?
    assert_equal "Lists", table.fetch("recording_studio.lists.index.title")
    assert_equal I18n.t("recording_studio.lists.index.totally_absent_for_missing_yml"),
                 RecordingStudio.t("recording_studio.lists.index.totally_absent_for_missing_yml")
  end

  test "lazy keys pass through like I18n.t" do
    I18n.with_locale(:en) do
      assert_equal I18n.t(".lazy_key_without_scope"), RecordingStudio.t(".lazy_key_without_scope")
    end
  end

  test "nil key matches I18n.t without raising a gem-specific error" do
    i18n_error = nil
    rs_error = nil
    i18n_result = begin
      I18n.t(nil)
    rescue StandardError => e
      i18n_error = e.class
      :raised
    end
    rs_result = begin
      RecordingStudio.t(nil)
    rescue StandardError => e
      rs_error = e.class
      :raised
    end

    if i18n_error.nil?
      assert_nil rs_error
    else
      assert_equal i18n_error, rs_error
    end
    if i18n_result == :raised
      assert_equal :raised, rs_result
    elsif i18n_result.nil?
      assert_nil rs_result
    else
      assert_equal i18n_result, rs_result
    end
  end

  test "global I18n config snapshot is unchanged by RecordingStudio.t" do
    before = i18n_config_snapshot

    RecordingStudio.t("recording_studio.lists.index.title")
    I18n.with_locale(:de) do
      RecordingStudio.t("recording_studio.lists.index.title")
      RecordingStudio.t("not_a_gem_key")
    end

    assert_equal before, i18n_config_snapshot
  end

  private

  def assert_parity(key, **options)
    expected = I18n.t(key, **options)
    actual = RecordingStudio.t(key, **options)
    assert_equal expected, actual, "parity failed for #{key.inspect} options=#{options.inspect}"
    return unless actual.is_a?(String) && key.to_s.match?(/(\b|_|\.)html\z/)

    assert_equal expected.html_safe?, actual.html_safe?
  end

  def assert_raise_parity(key, **options)
    i18n_error = assert_raises(I18n::MissingTranslationData) { I18n.t(key, **options) }
    rs_error = assert_raises(I18n::MissingTranslationData) { RecordingStudio.t(key, **options) }
    assert_equal i18n_error.message, rs_error.message
  end

  def i18n_config_snapshot
    {
      load_path: I18n.load_path.map { |path| File.expand_path(path) },
      available_locales: Array(I18n.available_locales).map(&:to_sym).sort,
      exception_handler: I18n.exception_handler,
      enforce_available_locales: I18n.enforce_available_locales,
      fallbacks_class: (I18n.fallbacks.class.name if I18n.respond_to?(:fallbacks)),
      fallbacks_de: (I18n.fallbacks[:de].dup if I18n.respond_to?(:fallbacks)),
      fallbacks_fr: (I18n.fallbacks[:fr].dup if I18n.respond_to?(:fallbacks)),
      fallbacks_en: (I18n.fallbacks[:en].dup if I18n.respond_to?(:fallbacks))
    }
  end

  def flatten_locale_keys(node, prefix)
    case node
    when Hash
      node.each_with_object({}) do |(key, value), result|
        result.merge!(flatten_locale_keys(value, prefix + [key.to_s]))
      end
    else
      { prefix.join(".") => node }
    end
  end

  # Mutate the initialized backend hash. store_translations after I18n.reload!
  # is unreliable because the next lookup re-inits from load_path.
  def delete_loaded_translation!(locale, full_key)
    mutate_loaded_translation!(locale, full_key) { |node, leaf| node.delete(leaf) }
  end

  def write_loaded_translation!(locale, full_key, value)
    mutate_loaded_translation!(locale, full_key) { |node, leaf| node[leaf] = value }
  end

  def mutate_loaded_translation!(locale, full_key)
    I18n.exists?(full_key, locale) # ensure translations are loaded
    parts = full_key.split(".").map(&:to_sym)
    leaf = parts.pop
    translations = I18n.backend.send(:translations)
    locale_key = locale.to_sym
    translations[locale_key] = translations[locale_key].dup if translations[locale_key].frozen?

    node = translations[locale_key]
    parts.each do |part|
      break unless node.is_a?(Hash) && node[part].is_a?(Hash)

      node[part] = node[part].dup if node[part].frozen?
      node = node[part]
    end
    yield node, leaf if node.is_a?(Hash)
  end
end
