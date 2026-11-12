# frozen_string_literal: true

require "test_helper"

class ListsApiTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "lists-api-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    @root = RecordingStudio.root_recording_for(Workspace.create!(name: "Lists API #{SecureRandom.hex(4)}"))
    grant_owner_access!(actor: @user, recording: @root)
    @page = record_page(@root, "Member")
    @list = RecordingStudio::Lists.create(parent: @root, name: "Reading", description: "Magazines", actor: @user)
    @edit_token = issue_token(role: :edit)
    @view_token = issue_token(role: :view)
  end

  test "edit token can create show update list items and delete" do
    post "/recording_studio_api/api/v1/lists",
         headers: json_headers(@edit_token),
         params: { parent_id: @root.id, name: "Shelf", description: "Notes" },
         as: :json
    assert_response :created
    created_id = response.parsed_body.fetch("id")
    assert_equal "Shelf", response.parsed_body.fetch("name")

    get "/recording_studio_api/api/v1/lists",
        headers: json_headers(@edit_token),
        params: { parent_id: @root.id }
    assert_response :success
    names = response.parsed_body.fetch("records").map { |record| record.fetch("name") }
    assert_includes names, "Reading"
    assert_includes names, "Shelf"

    get "/recording_studio_api/api/v1/lists/#{created_id}", headers: json_headers(@edit_token)
    assert_response :success
    assert_equal "Shelf", response.parsed_body.fetch("name")

    patch "/recording_studio_api/api/v1/lists/#{created_id}",
          headers: json_headers(@edit_token),
          params: { name: "Edited", description: "Kept" },
          as: :json
    assert_response :success
    assert_equal "Edited", response.parsed_body.fetch("name")

    post "/recording_studio_api/api/v1/lists/#{created_id}/actions/add",
         headers: json_headers(@edit_token),
         params: { recording_id: @page.id },
         as: :json
    assert_response :success

    get "/recording_studio_api/api/v1/lists/#{created_id}/actions/items", headers: json_headers(@edit_token)
    assert_response :success
    item_ids = response.parsed_body.fetch("records").map { |record| record.fetch("id") }
    assert_includes item_ids, @page.id

    get "/recording_studio_api/api/v1/lists/#{created_id}/actions/addable", headers: json_headers(@edit_token)
    assert_response :success
    addable_ids = response.parsed_body.fetch("records").map { |record| record.fetch("id") }
    refute_includes addable_ids, @page.id
    refute_includes addable_ids, created_id

    post "/recording_studio_api/api/v1/lists/#{created_id}/actions/remove",
         headers: json_headers(@edit_token),
         params: { recording_id: @page.id },
         as: :json
    assert_response :success
    refute_includes RecordingStudio::Lists.items(created_id).map(&:id), @page.id

    delete "/recording_studio_api/api/v1/lists/#{created_id}", headers: json_headers(@edit_token)
    assert_response :success
    refute RecordingStudio::Recording.exists?(created_id)
  end

  test "view token can show and is forbidden from writes" do
    get "/recording_studio_api/api/v1/lists/#{@list.id}", headers: json_headers(@view_token)
    assert_response :success

    get "/recording_studio_api/api/v1/lists/#{@list.id}/actions/items", headers: json_headers(@view_token)
    assert_response :success

    get "/recording_studio_api/api/v1/lists/#{@list.id}/actions/addable", headers: json_headers(@view_token)
    assert_response :success

    post "/recording_studio_api/api/v1/lists",
         headers: json_headers(@view_token),
         params: { parent_id: @root.id, name: "Denied" },
         as: :json
    assert_response :forbidden

    patch "/recording_studio_api/api/v1/lists/#{@list.id}",
          headers: json_headers(@view_token),
          params: { name: "Taken" },
          as: :json
    assert_response :forbidden
    assert_equal "Reading", @list.reload.name

    post "/recording_studio_api/api/v1/lists/#{@list.id}/actions/add",
         headers: json_headers(@view_token),
         params: { recording_id: @page.id },
         as: :json
    assert_response :forbidden

    post "/recording_studio_api/api/v1/lists/#{@list.id}/actions/remove",
         headers: json_headers(@view_token),
         params: { recording_id: @page.id },
         as: :json
    assert_response :forbidden

    delete "/recording_studio_api/api/v1/lists/#{@list.id}", headers: json_headers(@view_token)
    assert_response :forbidden
    assert RecordingStudio::Recording.exists?(@list.id)
  end

  test "a list in another workspace is not found" do
    other_root = RecordingStudio.root_recording_for(Workspace.create!(name: "Other #{SecureRandom.hex(4)}"))
    other_user = User.create!(
      email: "lists-api-other-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    grant_owner_access!(actor: other_user, recording: other_root)
    other_list = RecordingStudio::Lists.create(parent: other_root, name: "Elsewhere", actor: other_user)

    get "/recording_studio_api/api/v1/lists/#{other_list.id}", headers: json_headers(@edit_token)
    assert_response :not_found

    patch "/recording_studio_api/api/v1/lists/#{other_list.id}",
          headers: json_headers(@edit_token),
          params: { name: "Stolen" },
          as: :json
    assert_response :not_found
    assert_equal "Elsewhere", other_list.reload.name

    post "/recording_studio_api/api/v1/lists/#{other_list.id}/actions/add",
         headers: json_headers(@edit_token),
         params: { recording_id: @page.id },
         as: :json
    assert_response :not_found
  end

  test "add enforces same-root no-self and lock through the gem" do
    elsewhere = RecordingStudio.root_recording_for(Workspace.create!(name: "Foreign #{SecureRandom.hex(4)}"))
    foreign = record_page(elsewhere, "Foreign")

    post "/recording_studio_api/api/v1/lists/#{@list.id}/actions/add",
         headers: json_headers(@edit_token),
         params: { recording_id: @list.id },
         as: :json
    assert_response :unprocessable_entity
    assert_includes response.body, "A list can't contain itself."

    post "/recording_studio_api/api/v1/lists/#{@list.id}/actions/add",
         headers: json_headers(@edit_token),
         params: { recording_id: foreign.id },
         as: :json
    assert_response :unprocessable_entity
    assert_includes response.body, "That lives somewhere else."

    first = record_page(@root, "First")
    second = record_page(@root, "Second")
    threads = [
      Thread.new { add_member(@list.id, first.id, @edit_token) },
      Thread.new { add_member(@list.id, second.id, @edit_token) }
    ]
    statuses = threads.map(&:value)
    assert(statuses.all? { |status| status == 200 })
    assert_equal [first.id, second.id].sort, RecordingStudio::Lists.items(@list).map(&:id).sort
  end

  private

  def json_headers(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def issue_token(role:)
    result = RecordingStudioApi::Services::IssueTestCredential.call(
      api: :public,
      actor: @user,
      access_point_recording: @root,
      role: role,
      name: "lists-api-#{role}-#{SecureRandom.hex(4)}"
    )
    raise result.error if result.failure?

    result.value.fetch(:access_token)
  end

  def grant_owner_access!(actor:, recording:)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    raise result.error if result.failure?
  end

  def record_page(root, title)
    RecordingStudio.record!(
      action: "created",
      recordable: Page.new(title: "#{title} #{SecureRandom.hex(4)}"),
      root_recording: root,
      parent_recording: root,
      actor: @user
    ).recording
  end

  def add_member(list_id, recording_id, token)
    post "/recording_studio_api/api/v1/lists/#{list_id}/actions/add",
         headers: json_headers(token),
         params: { recording_id: recording_id },
         as: :json
    response.status
  end
end
