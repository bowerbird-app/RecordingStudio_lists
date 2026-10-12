# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

# Proves a host nested `recording_studio.lists.*` override in
# config/locales wins over gem English on a real page. Uses
# js.save_failed (Stimulus data attribute only) so the dummy
# UI and other rendered tests keep default English for common labels.
# Does not touch I18n.load_path.
class ListsBootOrderHostOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @original_load_path = I18n.load_path.dup
    @user = User.create!(
      email: "lists-boot-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    @workspace = Workspace.create!(name: "! Boot Lists #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @page = RecordingStudio.record!(
      action: "created",
      recordable: Page.new(title: "Boot Page #{SecureRandom.hex(4)}"),
      root_recording: @root,
      parent_recording: @root,
      actor: @user
    ).recording
    sign_in @user
    select_root(@root)
  end

  teardown do
    assert_equal @original_load_path, I18n.load_path,
                 "tests must not leave I18n.load_path modified"
  end

  test "host nested locale override wins on the home add-to-list form data attribute" do
    host_locale = Rails.root.join("config/locales/recording_studio_lists_host.en.yml")
    assert File.exist?(host_locale), "expected host override file at #{host_locale}"

    get "/"

    assert_response :success
    assert_includes response.body, "HOST That didn&#39;t save. Try again."
    refute_includes response.body, 'data-save-failed="That didn&#39;t save. Try again."'
    assert_equal(
      "HOST That didn't save. Try again.",
      I18n.t("recording_studio.lists.js.save_failed", raise: true)
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
end
