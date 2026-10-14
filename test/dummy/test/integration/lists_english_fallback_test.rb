# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

# Behavioral renders: a locale without translations shows loaded / shipped
# English for gem call sites. Uses :de so boot-loaded host :en overrides can
# still win on the English fallback path. Targets real lists pages and real
# shipped keys (no probe routes).
class ListsEnglishFallbackTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_lists_host.en.yml")
  HOME_KEY = "recording_studio.lists.index.home"
  TITLE_KEY = "recording_studio.lists.index.title"
  EMPTY_KEY = "recording_studio.lists.index.empty"

  setup do
    @previous_locales = I18n.available_locales
    I18n.available_locales = (@previous_locales + %i[en de fr]).uniq
    @load_path_before = I18n.load_path.dup
    @user = User.create!(
      email: "lists-fallback-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    @workspace = Workspace.create!(name: "! Fallback Lists #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    sign_in @user
    select_root(@root)
  end

  teardown do
    I18n.locale = I18n.default_locale
    I18n.available_locales = @previous_locales if @previous_locales
    assert_equal @load_path_before, I18n.load_path,
                 "test must not leave I18n.load_path modified"
  end

  test "shipped english table is present after boot before any helper call" do
    table = RecordingStudio::Translation.instance_variable_get(:@shipped_english)
    refute_nil table, "engine initializer must eager-load shipped english before first call"
    refute_empty table
    assert_equal "Lists", table.fetch(TITLE_KEY)
    assert_equal "Home", table.fetch(HOME_KEY)
  end

  test "rails reloader resets shipped english to a new object" do
    before = RecordingStudio::Translation.shipped_english
    begin
      Rails.application.reloader.reload!
    rescue StandardError
      # Dummy host initializers may re-register resources on full reload.
    end
    after = RecordingStudio::Translation.shipped_english

    refute_same before, after
    assert_equal before.fetch(TITLE_KEY), after.fetch(TITLE_KEY)
    assert_predicate after, :frozen?
  end

  test "missing locale without translations renders gem english on lists index" do
    I18n.with_locale(:de) do
      refute I18n.exists?(TITLE_KEY, :de)

      get "/lists"

      assert_response :success
      assert_select "h1", text: "Lists"
      assert_select "h3", text: "No lists yet."
      refute_lists_translation_missing!(response.body)
    end
  end

  test "english render matches gem english strings from main" do
    I18n.with_locale(:en) do
      get "/lists"
      assert_response :success
      assert_select "h1", text: "Lists"
      assert_select "h3", text: "No lists yet."
      assert_includes response.body, "HOST Home"
      refute_lists_translation_missing!(response.body)
    end
  end

  test "deleted english key on lists index shows shipped title with raise-on-missing on and off" do
    delete_loaded_translation!(:en, TITLE_KEY)
    delete_loaded_translation!(:fr, TITLE_KEY)

    refute I18n.exists?(TITLE_KEY, :en)
    refute I18n.exists?(TITLE_KEY, :fr)

    previous_raise = ActionView::Helpers::TranslationHelper.raise_on_missing_translations

    [false, true].each do |raise_on_missing|
      ActionView::Helpers::TranslationHelper.raise_on_missing_translations = raise_on_missing

      %i[en fr].each do |locale|
        I18n.with_locale(locale) do
          get "/lists"

          assert_response :success, "expected 200 in #{locale} raise=#{raise_on_missing}"
          assert_select "h1", text: "Lists"
          assert_includes response.body, "No lists yet."
          refute_lists_translation_missing!(response.body)
        end
      end
    end
  ensure
    ActionView::Helpers::TranslationHelper.raise_on_missing_translations = previous_raise
    I18n.reload!
  end

  test "boot-loaded host english override wins on lists index back label via de fallback" do
    assert File.exist?(BOOT_HOST_LOCALE),
           "expected boot-loaded host override at #{BOOT_HOST_LOCALE}"
    # Force I18n to initialize before asserting HOST.
    I18n.t(HOME_KEY)
    assert_equal "HOST Home", I18n.t(HOME_KEY, raise: true)
    assert_equal @load_path_before, I18n.load_path
    refute_equal "Home", I18n.t(HOME_KEY), "main English must be absent under the host override"

    I18n.with_locale(:de) do
      refute I18n.exists?(HOME_KEY, :de)

      get "/lists"

      assert_response :success
      assert_includes response.body, "HOST Home"
      assert_select "h1", text: "Lists"
      refute_includes response.body, ">Home<"
      refute_lists_translation_missing!(response.body)
    end
  end

  private

  def select_root(root)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: { root_recording_id: root.id, return_to: "/" }
    }
    follow_redirect!
  end

  def refute_lists_translation_missing!(body)
    refute_match(/translation missing/i, body)
    refute_match(/recording_studio\.lists\./, body)
  end

  def delete_loaded_translation!(locale, full_key)
    I18n.exists?(full_key, locale)
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
    node.delete(leaf) if node.is_a?(Hash)
  end
end
