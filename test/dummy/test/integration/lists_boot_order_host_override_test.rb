# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

# Proves a host nested `recording_studio.lists.*` override in
# config/locales wins over gem English on a real page. Uses
# index.home (page-nav back label) so other list-screen assertions
# keep default English for title/empty/new. Does not touch I18n.load_path.
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
    sign_in @user
    select_root(@root)
  end

  teardown do
    assert_equal @original_load_path, I18n.load_path,
                 "tests must not leave I18n.load_path modified"
  end

  test "host nested locale override wins on lists index back label" do
    host_locale = Rails.root.join("config/locales/recording_studio_lists_host.en.yml")
    assert File.exist?(host_locale), "expected host override file at #{host_locale}"

    get "/lists"

    assert_response :success
    assert_includes response.body, "HOST Home"
    assert_select "h1", text: "Lists"
    assert_select "h3", text: "No lists yet."
    assert_equal "HOST Home", I18n.t("recording_studio.lists.index.home", raise: true)
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
