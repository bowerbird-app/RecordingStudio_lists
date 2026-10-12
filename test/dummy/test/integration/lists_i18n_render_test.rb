# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

# Render-level English asserts for wave 2 non-view copy. Host overrides use
# I18n.backend.store_translations (no runtime I18n.load_path <<).
class ListsI18nRenderTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "lists-i18n-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    @workspace = Workspace.create!(name: "! I18n Lists #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @page = RecordingStudio.record!(
      action: "created",
      recordable: Page.new(title: "I18n Page #{SecureRandom.hex(4)}"),
      root_recording: @root,
      parent_recording: @root,
      actor: @user
    ).recording
    sign_in @user
    select_root(@root)
  end

  test "lists index and add-to-list trigger render main english" do
    get "/lists"

    assert_response :success
    assert_select "h1", text: "Lists"
    assert_select "h3", text: "No lists yet."

    get "/"

    assert_response :success
    assert_select "button", text: "Add to list"
    assert_includes response.body, 'data-blank-name="Name can&#39;t be blank."'
    assert_includes response.body, 'data-save-failed="That didn&#39;t save. Try again."'
  end

  test "create flash and blank name render main english" do
    post "/lists", params: {
      list: { name: "Reading" },
      idempotency_key: "i18n-create-#{SecureRandom.hex(4)}"
    }

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "List created."

    post "/lists", params: {
      list: { name: "  " },
      idempotency_key: "i18n-blank-#{SecureRandom.hex(4)}"
    }

    assert_response :unprocessable_entity
    assert_select "p", text: "Name can't be blank."
  end

  test "host store_translations override wins on lists index without touching load path" do
    original_load_path = I18n.load_path.dup

    with_restored_i18n_backend do
      I18n.backend.store_translations(
        :en,
        recording_studio: {
          lists: {
            index: {
              title: "HOST Lists",
              empty: "HOST No lists yet."
            },
            add_to_list: {
              trigger: "HOST Add to list"
            }
          }
        }
      )

      get "/lists"

      assert_response :success
      assert_select "h1", text: "HOST Lists"
      assert_select "h3", text: "HOST No lists yet."

      get "/"

      assert_response :success
      assert_select "button", text: "HOST Add to list"
    end

    assert_equal original_load_path, I18n.load_path

    get "/lists"

    assert_response :success
    assert_select "h1", text: "Lists"
    assert_select "h3", text: "No lists yet."
  end

  test "different root membership alert translates at the render site by error class" do
    list = RecordingStudio::Lists.create(parent: @root, name: "Shelf", actor: @user)
    other = Workspace.create!(name: "Z I18n #{SecureRandom.hex(4)}")
    other_root = RecordingStudio.root_recording_for(other)
    other_page = RecordingStudio.record!(
      action: "created",
      recordable: Page.new(title: "Elsewhere #{SecureRandom.hex(4)}"),
      root_recording: other_root,
      parent_recording: other_root,
      actor: @user
    ).recording

    with_restored_i18n_backend do
      I18n.backend.store_translations(
        :en,
        recording_studio: {
          lists: {
            errors: {
              different_root: "HOST That lives somewhere else."
            }
          }
        }
      )

      post "/lists/#{list.id}/items", params: { recording_id: other_page.id, return_to: "/" }

      assert_redirected_to "/"
      follow_redirect!
      assert_includes response.body, "HOST That lives somewhere else."
    end

    assert_equal(
      "That lives somewhere else.",
      RecordingStudio::Lists::DifferentRoot.new.message
    )
  end

  private

  def select_root(root)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: { root_recording_id: root.id, return_to: "/" }
    }
    follow_redirect!
  end

  def with_restored_i18n_backend
    previous_translations = i18n_backend_translations_snapshot
    yield
  ensure
    restore_i18n_backend_translations(previous_translations) if previous_translations
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
