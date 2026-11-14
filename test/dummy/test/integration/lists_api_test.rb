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

    post "/recording_studio_api/api/v1/lists/#{created_id}/actions/list_add",
         headers: json_headers(@edit_token),
         params: { recording_id: @page.id },
         as: :json
    assert_response :success

    get "/recording_studio_api/api/v1/lists/#{created_id}/actions/list_items", headers: json_headers(@edit_token)
    assert_response :success
    item_ids = response.parsed_body.fetch("records").map { |record| record.fetch("id") }
    assert_includes item_ids, @page.id

    get "/recording_studio_api/api/v1/lists/#{created_id}/actions/list_addable", headers: json_headers(@edit_token)
    assert_response :success
    addable_ids = response.parsed_body.fetch("records").map { |record| record.fetch("id") }
    refute_includes addable_ids, @page.id
    refute_includes addable_ids, created_id

    post "/recording_studio_api/api/v1/lists/#{created_id}/actions/list_remove",
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

    get "/recording_studio_api/api/v1/lists/#{@list.id}/actions/list_items", headers: json_headers(@view_token)
    assert_response :success

    get "/recording_studio_api/api/v1/lists/#{@list.id}/actions/list_addable", headers: json_headers(@view_token)
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

    post "/recording_studio_api/api/v1/lists/#{@list.id}/actions/list_add",
         headers: json_headers(@view_token),
         params: { recording_id: @page.id },
         as: :json
    assert_response :forbidden

    post "/recording_studio_api/api/v1/lists/#{@list.id}/actions/list_remove",
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

    post "/recording_studio_api/api/v1/lists/#{other_list.id}/actions/list_add",
         headers: json_headers(@edit_token),
         params: { recording_id: @page.id },
         as: :json
    assert_response :not_found
  end

  test "add enforces same-root no-self and lock through the gem" do
    elsewhere = RecordingStudio.root_recording_for(Workspace.create!(name: "Foreign #{SecureRandom.hex(4)}"))
    foreign = record_page(elsewhere, "Foreign")

    post "/recording_studio_api/api/v1/lists/#{@list.id}/actions/list_add",
         headers: json_headers(@edit_token),
         params: { recording_id: @list.id },
         as: :json
    assert_response :unprocessable_entity
    assert_includes response.body, "A list can't contain itself."

    post "/recording_studio_api/api/v1/lists/#{@list.id}/actions/list_add",
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

  test "create with a list parent returns 422 ParentNotAllowed" do
    post "/recording_studio_api/api/v1/lists",
         headers: json_headers(@edit_token),
         params: { parent_id: @list.id, name: "Nested" },
         as: :json
    assert_response :unprocessable_entity
    assert_includes response.body, RecordingStudio::Lists::ParentNotAllowed.new.message
  end

  test "index excludes a list the actor cannot view" do
    other_root = RecordingStudio.root_recording_for(Workspace.create!(name: "Hidden #{SecureRandom.hex(4)}"))
    other_user = User.create!(
      email: "lists-api-hidden-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    grant_owner_access!(actor: other_user, recording: other_root)
    hidden = RecordingStudio::Lists.create(parent: other_root, name: "Hidden #{SecureRandom.hex(4)}", actor: other_user)

    get "/recording_studio_api/api/v1/lists",
        headers: json_headers(@edit_token),
        params: { parent_id: @root.id }
    assert_response :success
    ids = response.parsed_body.fetch("records").map { |record| record.fetch("id") }
    assert_includes ids, @list.id
    refute_includes ids, hidden.id
    assert_includes RecordingStudio::Lists.lists(other_root).map(&:id), hidden.id
    assert_empty RecordingStudioLists::AccessibleLists.for(
      actor: @user, parent: other_root, minimum_role: :view
    )
  end

  test "another orderable type does not get list membership actions" do
    page = record_page(@root, "Orderable page")

    RecordingStudioLists::Api::CAPABILITY_ACTIONS.each do |action|
      registration = RecordingStudioApi.capability_action(action)
      refute registration.applicable_to?("Page"), "#{action} leaked to Page"
      refute RecordingStudioApi.capability_action_enabled_for?(registration, "Page"),
             "#{action} enabled for Page"
      assert registration.applicable_to?("RecordingStudio::Lists::List")
    end

    post "/recording_studio_api/api/v1/pages/#{page.id}/actions/list_add",
         headers: json_headers(@edit_token),
         params: { recording_id: @list.id },
         as: :json
    assert_response :unprocessable_entity
  end

  test "writes reject a missing parent, a blank name, and a missing member" do
    post "/recording_studio_api/api/v1/lists",
         headers: json_headers(@edit_token),
         params: { name: "Shelf" },
         as: :json
    assert_response :unprocessable_entity
    assert_includes response.body, "parent_id is required"

    get "/recording_studio_api/api/v1/lists", headers: json_headers(@edit_token)
    assert_response :unprocessable_entity
    assert_includes response.body, "parent_id is required"

    post "/recording_studio_api/api/v1/lists",
         headers: json_headers(@edit_token),
         params: { parent_id: @root.id, name: "   " },
         as: :json
    assert_response :unprocessable_entity
    assert_includes response.body, "Name can't be blank."

    patch "/recording_studio_api/api/v1/lists/#{@list.id}",
          headers: json_headers(@edit_token),
          params: { name: "" },
          as: :json
    assert_response :unprocessable_entity
    assert_equal "Reading", @list.reload.name

    post "/recording_studio_api/api/v1/lists/#{@list.id}/actions/list_add",
         headers: json_headers(@edit_token),
         params: { recording_id: SecureRandom.uuid },
         as: :json
    assert_response :unprocessable_entity
    assert_includes response.body, "Pick something to add."

    item = RecordingStudio::Lists.add(@list, @page)
    child = @list.child_recordings.find { |recording| recording.recordable.item_recording_id == item.id }
    post "/recording_studio_api/api/v1/lists/#{@list.id}/actions/list_add",
         headers: json_headers(@edit_token),
         params: { recording_id: child.id },
         as: :json
    assert_response :unprocessable_entity
    assert_includes response.body, "That can't go on a list."

    post "/recording_studio_api/api/v1/lists",
         headers: json_headers(@edit_token),
         params: { parent_id: SecureRandom.uuid, name: "Lost" },
         as: :json
    assert_response :not_found
    assert_includes response.body, "Parent resource was not found"
  end

  test "index paginates with limit and pagination_token" do
    extra = RecordingStudio::Lists.create(parent: @root, name: "Also #{SecureRandom.hex(4)}", actor: @user)
    expected_ids = [@list.id, extra.id].sort

    get "/recording_studio_api/api/v1/lists",
        headers: json_headers(@edit_token),
        params: { parent_id: @root.id, limit: 1 }
    assert_response :success
    first_payload = response.parsed_body
    first_ids = first_payload.fetch("records").map { |record| record.fetch("id") }
    first_meta = first_payload.fetch("meta")
    assert_equal 1, first_ids.size
    refute_nil first_meta.fetch("next_pagination_token")

    get "/recording_studio_api/api/v1/lists",
        headers: json_headers(@edit_token),
        params: {
          parent_id: @root.id,
          limit: 1,
          pagination_token: first_meta.fetch("next_pagination_token")
        }
    assert_response :success
    second_payload = response.parsed_body
    second_ids = second_payload.fetch("records").map { |record| record.fetch("id") }
    assert_equal 1, second_ids.size
    assert_equal expected_ids, (first_ids + second_ids).sort
    assert_nil second_payload.fetch("meta").fetch("next_pagination_token")
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
    post "/recording_studio_api/api/v1/lists/#{list_id}/actions/list_add",
         headers: json_headers(token),
         params: { recording_id: recording_id },
         as: :json
    response.status
  end
end
