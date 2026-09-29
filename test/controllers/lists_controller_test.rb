# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

require "devise/test/integration_helpers"
require "rails/test_help"

class ListsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "lists-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    @workspace = Workspace.create!(name: "! Lists #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    @page = RecordingStudio.record!(
      action: "created",
      recordable: Page.new(title: "Dezeen Board #{SecureRandom.hex(4)}"),
      root_recording: @root,
      parent_recording: @root,
      actor: @user
    ).recording
    sign_in @user
  end

  test "index and new list screens render" do
    get "/lists"

    assert_response :success
    assert_select "h1", text: "Lists"
    assert_select "h3", text: "No lists yet."
    assert_includes response.body, "New list"

    get "/lists/new"

    assert_response :success
    assert_select "h1", text: "New list"
    assert_select "input[name='list[name]']"
    assert_select "textarea[name='list[description]']"
    assert_select "button", text: "Create list"
    assert_select "input[name='idempotency_key']"
  end

  test "create show add remove and delete" do
    post "/lists", params: { list: { name: "  " }, idempotency_key: "blank-#{SecureRandom.hex(4)}" }

    assert_response :unprocessable_entity
    assert_select "p", text: "Name can't be blank."

    key = "create-#{SecureRandom.hex(4)}"
    post "/lists", params: {
      list: { name: "Reading", description: "Magazines" },
      idempotency_key: key
    }

    assert_response :redirect
    show_path = URI.parse(response.headers["Location"]).path
    follow_redirect!

    assert_response :success
    assert_includes response.body, "Reading"
    assert_includes response.body, "Magazines"
    assert_includes response.body, "0 items"
    assert_includes response.body, "List created."

    post "/lists", params: {
      list: { name: "Duplicate", description: "Ignored" },
      idempotency_key: key
    }

    assert_redirected_to show_path
    assert_equal 1, RecordingStudio::Lists::List.where(name: "Reading").count

    get "/lists"
    assert_includes response.body, "Reading"
    assert_select "tbody tr", text: /Reading/ do
      assert_select "a", text: "Reading"
    end

    post "#{show_path}/items", params: { recording_id: @page.id }

    assert_redirected_to show_path
    follow_redirect!

    assert_includes response.body, @page.name
    assert_includes response.body, "1 item"
    assert_includes response.body, "Added."
    assert_select "tbody tr", text: /#{Regexp.escape(@page.name)}/ do
      assert_select "button", text: "Remove"
    end

    delete "#{show_path}/items/#{@page.id}"

    assert_redirected_to show_path
    assert RecordingStudio::Recording.exists?(@page.id)
    follow_redirect!
    assert_includes response.body, "Removed."

    list_id = show_path.split("/").last
    delete show_path

    assert_redirected_to "/lists"
    refute RecordingStudio::Recording.exists?(list_id)
    assert RecordingStudio::Recording.exists?(@page.id)
    follow_redirect!
    assert_includes response.body, "List deleted."
  end
end
