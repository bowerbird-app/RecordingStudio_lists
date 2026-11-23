# frozen_string_literal: true

require "test_helper"

class ListsNamedMcpToolsTest < ActionDispatch::IntegrationTest
  PUBLIC_TOOLS = %w[
    list_lists show_list create_list update_list delete_list
    add_to_list remove_from_list list_list_members
  ].freeze

  setup do
    @user = User.create!(
      email: "lists-mcp-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    @root = RecordingStudio.create_root_recording!(
      Workspace.create!(name: "Lists MCP #{SecureRandom.hex(4)}"),
      actor: @user
    )
    grant_owner_access!(actor: @user, recording: @root)
    @page = record_page(@root, "Member")
    @list = RecordingStudio::Lists.create(parent: @root, name: "Reading", description: "Magazines", actor: @user)
    @edit_token = issue_token(role: :edit)
    @view_token = issue_token(role: :view)
  end

  test "named tools map onto the public list API" do
    names = RecordingStudioLists::McpCopy.tool_names

    assert_equal PUBLIC_TOOLS, names.fetch(:public)
    assert_equal PUBLIC_TOOLS + %w[list_addable], names.fetch(:operations)

    get "/recording_studio_api/api/v1/lists",
        headers: json_headers(@edit_token),
        params: { parent_id: @root.id }
    assert_response :success
    assert_includes response.parsed_body.fetch("records").map { |record| record.fetch("id") }, @list.id

    get "/recording_studio_api/api/v1/lists/#{@list.id}", headers: json_headers(@edit_token)
    assert_response :success

    post "/recording_studio_api/api/v1/lists",
         headers: json_headers(@edit_token),
         params: { parent_id: @root.id, name: "Shelf" },
         as: :json
    assert_response :created
    created_id = response.parsed_body.fetch("id")

    patch "/recording_studio_api/api/v1/lists/#{created_id}",
          headers: json_headers(@edit_token),
          params: { name: "Edited", description: "Notes" },
          as: :json
    assert_response :success

    post "/recording_studio_api/api/v1/lists/#{created_id}/actions/list_add",
         headers: json_headers(@edit_token),
         params: { recording_id: @page.id },
         as: :json
    assert_response :success

    get "/recording_studio_api/api/v1/lists/#{created_id}/actions/list_items",
        headers: json_headers(@edit_token)
    assert_response :success
    assert_includes response.parsed_body.fetch("records").map { |record| record.fetch("id") }, @page.id

    post "/recording_studio_api/api/v1/lists/#{created_id}/actions/list_remove",
         headers: json_headers(@edit_token),
         params: { recording_id: @page.id },
         as: :json
    assert_response :success

    delete "/recording_studio_api/api/v1/lists/#{created_id}", headers: json_headers(@edit_token)
    assert_response :success
    refute RecordingStudio::Recording.exists?(created_id)
  end

  test "view token is forbidden from named write tools" do
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

  test "list_addable stays off the public API and on operations" do
    operations_existed = RecordingStudioApi.configuration.api_names.include?("operations")
    workspace_before = operations_registration("Workspace")
    list_before = operations_registration(RecordingStudioLists::Api::TYPE)

    get "/recording_studio_api/api/v1/lists/#{@list.id}/actions/list_addable",
        headers: json_headers(@edit_token)
    assert_response :unprocessable_entity

    RecordingStudioApi.configuration.api(:operations)
    unless RecordingStudioApi.recordable_registration_for("Workspace", api: :operations)
      RecordingStudioApi.register_recordable_type_api(
        "Workspace",
        api: :operations,
        operations: %i[show],
        serializer: ->(workspace, **) { { name: workspace.name } },
        output_keys: %i[name]
      )
    end
    RecordingStudioLists::Api.register_api(:operations)

    get "/recording_studio_api/apis/operations/v1/lists/#{@list.id}/actions/list_addable",
        headers: json_headers(issue_token(role: :view, api: :operations))
    assert_response :success
    assert_includes response.parsed_body.fetch("records").map { |record| record.fetch("id") }, @page.id
  ensure
    restore_operations_registrations(
      operations_existed: operations_existed,
      workspace_before: workspace_before,
      list_before: list_before
    )
  end

  test "mcp registration is a no-op in this dummy without RecordingStudioMcp" do
    refute RecordingStudioLists::McpCopy.mcp_available?
    assert_nil RecordingStudioLists::McpCopy.register!
  end

  private

  def json_headers(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def issue_token(role:, api: :public)
    result = RecordingStudioApi::Services::IssueTestCredential.call(
      api: api,
      actor: @user,
      access_point_recording: @root,
      role: role,
      name: "lists-mcp-#{role}-#{SecureRandom.hex(4)}"
    )
    raise result.error if result.failure?

    api_client = result.value.fetch(:api_client)
    api_client.update!(owner: @user) if api_client.owner != @user

    result.value.fetch(:access_token)
  end

  def grant_owner_access!(actor:, recording:)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
    raise result.error if result.failure?
  end

  def operations_registration(recordable_type)
    return unless RecordingStudioApi.configuration.api_names.include?("operations")

    RecordingStudioApi.recordable_registration_for(recordable_type, api: :operations)
  end

  def restore_operations_registrations(operations_existed:, workspace_before:, list_before:)
    return unless operations_existed

    restore_workspace_registration(workspace_before)
    restore_list_registration(list_before)
  end

  def restore_workspace_registration(registration)
    return unless registration

    RecordingStudioApi.register_recordable_type_api(
      "Workspace",
      api: :operations,
      operations: registration.operations,
      serializer: registration.serializer,
      output_keys: registration.output_keys
    )
  end

  def restore_list_registration(registration)
    return unless registration

    RecordingStudioLists::Api.register_api(:operations)
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
end
