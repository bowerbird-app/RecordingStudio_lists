# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ListsI18nHostOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_OVERRIDE_LOCALE = File.expand_path("../locales/lists_host_override.en.yml", __dir__).freeze

  setup do
    @original_load_path = I18n.load_path.dup
    @user = User.create!(
      email: "lists-host-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    @workspace = Workspace.create!(name: "! Host Lists #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    sign_in @user
    select_root(@root)
  end

  teardown do
    restore_i18n_backend!
    assert_equal @original_load_path, I18n.load_path,
                 "tests must not leave I18n.load_path modified"
  end

  test "host locale file override wins over gem english on lists index" do
    with_host_override_locale do
      get "/lists"

      assert_response :success
      assert_select "h1", text: "HOST Lists"
      assert_select "h3", text: "HOST No lists yet."
      assert_equal "HOST Lists", I18n.t("recording_studio.lists.index.title")
      assert_equal "HOST Add to list", I18n.t("recording_studio.lists.add_to_list.trigger")
    end

    get "/lists"

    assert_response :success
    assert_select "h1", text: "Lists"
    assert_select "h3", text: "No lists yet."
    refute_includes response.body, "HOST Lists"
    assert_equal @original_load_path, I18n.load_path
  end

  private

  def select_root(root)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: { root_recording_id: root.id, return_to: "/" }
    }
    follow_redirect!
  end

  def with_host_override_locale
    previous_load_path = I18n.load_path.dup
    previous_translations = i18n_backend_translations_snapshot
    expanded_override = File.expand_path(HOST_OVERRIDE_LOCALE)

    I18n.load_path.delete(expanded_override)
    I18n.load_path << expanded_override
    I18n.backend.load_translations(expanded_override)

    yield
  ensure
    I18n.load_path.replace(previous_load_path)
    restore_i18n_backend_translations(previous_translations) if previous_translations
  end

  def restore_i18n_backend!
    return unless defined?(@backend_snapshot_for_teardown) && @backend_snapshot_for_teardown

    restore_i18n_backend_translations(@backend_snapshot_for_teardown)
  end

  def i18n_backend_translations_snapshot
    backend = I18n.backend
    backend.send(:init_translations) unless backend.initialized?
    translations =
      if backend.respond_to?(:translations)
        backend.translations
      else
        backend.instance_variable_get(:@translations)
      end
    return unless translations

    deep_plain_copy(translations)
  end

  def restore_i18n_backend_translations(snapshot)
    backend = I18n.backend
    backend.instance_variable_set(:@translations, snapshot)
    backend.instance_variable_set(:@initialized, true) if backend.instance_variable_defined?(:@initialized)
  end

  def deep_plain_copy(value)
    case value
    when Hash
      value.each_with_object({}) { |(key, nested), copy| copy[key] = deep_plain_copy(nested) }
    when Array
      value.map { |nested| deep_plain_copy(nested) }
    else
      value
    end
  end
end
