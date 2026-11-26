# frozen_string_literal: true

require "test_helper"

class ListsApiTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "lists-api-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    @root = RecordingStudio.create_root_recording!(
      Workspace.create!(name: "Lists API #{SecureRandom.hex(4)}"),
      actor: @user
    )
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
    other_root = RecordingStudio.create_root_recording!(
      Workspace.create!(name: "Other #{SecureRandom.hex(4)}"),
      actor: @user
    )
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
    elsewhere = RecordingStudio.create_root_recording!(
      Workspace.create!(name: "Foreign #{SecureRandom.hex(4)}"),
      actor: @user
    )
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
    other_root = RecordingStudio.create_root_recording!(
      Workspace.create!(name: "Hidden #{SecureRandom.hex(4)}"),
      actor: @user
    )
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

    assert_nil RecordingStudioApi.capability_action(:list_addable)

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

    item = RecordingStudio::Lists.add(@list, @page, actor: @user)
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

  test "registered list tools and inputs keep plain descriptions" do
    catalog = RecordingStudioApi.documentation_catalog(version: "v1")
    section = catalog.fetch(:resources).find { |entry| entry.fetch(:recordable_type) == "RecordingStudio::Lists::List" }
    endpoints = section.fetch(:endpoints)
    texts = []
    endpoints.each { |endpoint| collect_descriptions(endpoint, texts) }

    assert_includes endpoints.map { |endpoint| endpoint.fetch(:action) }, "resources#index"
    assert(endpoints.any? { |endpoint| endpoint.fetch(:path).end_with?("/actions/list_add") })
    assert(endpoints.any? { |endpoint| endpoint.fetch(:path).end_with?("/actions/list_items") })
    texts.each do |text|
      refute_empty text.strip
      refute_includes text, "RecordingStudio::"
      refute_includes text, "Path parameter"
    end
    document = RecordingStudioApi.openapi_document(version: "v1")
    index = document.dig(:paths, "/recording_studio_api/api/v1/lists", "get")
    assert_includes index.fetch(:description), "paged"
    registration = RecordingStudioApi.recordable_registration_for("RecordingStudio::Lists::List")
    assert_equal ["Lists"], registration.openapi.fetch(:tags)
    index_names = registration.openapi.dig(:index, :parameters).map { |parameter| parameter.fetch(:name) }
    assert_includes index_names, "parent_id"
    %w[q filter[name] filter[description]].each { |name| refute_includes index_names, name }
    parameters = index.fetch(:parameters)
    assert_includes parameters.map { |parameter| parameter.fetch("name") }, "parent_id"
    count = parameters.find { |parameter| parameter.fetch("name") == "count" }
    refute_includes count.fetch("description"), "not loaded"
    add = document.dig(:paths, "/recording_studio_api/api/v1/lists/{id}/actions/list_add", "post")
    recording_id = add.dig(:requestBody, :content, "application/json", :schema, :properties, "recording_id")
    recording_description = recording_id[:description] || recording_id["description"]
    assert_includes recording_description, "already have"
    refute_includes recording_description, "List addable records"
    list_id = add.fetch(:parameters).find { |parameter| (parameter["name"] || parameter[:name]) == "id" }
    assert_includes list_id["description"] || list_id[:description], "index"
    assert_membership_titles(document)
    assert_resource_titles(document)
    assert_no_type_first_list_copy(document)
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

  test "public OpenAPI and documentation catalog omit list_addable" do
    document = RecordingStudioApi.openapi_document(version: "v1", api: :public)
    catalog = RecordingStudioApi.documentation_catalog(version: "v1", api: :public)
    registration = RecordingStudioApi.recordable_registration_for("RecordingStudio::Lists::List", api: :public)

    assert_empty paths_named(document, "list_addable")
    refute catalog_paths(catalog).any? { |path| path.include?("list_addable") }
    refute_includes Array(registration.capability_actions).map(&:to_sym), :list_addable
    assert_nil RecordingStudioApi.capability_action(:list_addable, api: :public)

    get "/recording_studio_api/api/v1/lists/#{@list.id}/actions/list_addable", headers: json_headers(@edit_token)
    assert_response :unprocessable_entity
    assert_equal "unsupported_action", response.parsed_body.dig("error", "code")
    assert_includes response.parsed_body.dig("error", "message"), "list_addable"
  end

  test "register! skips the operations API and leaves the public API" do
    RecordingStudioApi.configuration.api(:operations)
    before = RecordingStudioApi.recordable_registration_for("RecordingStudio::Lists::List", api: :operations)
    RecordingStudioLists::Api.register!

    assert_same before, RecordingStudioApi.recordable_registration_for("RecordingStudio::Lists::List", api: :operations)
    assert RecordingStudioApi.recordable_registration_for("RecordingStudio::Lists::List", api: :public)
    assert_nil RecordingStudioApi.capability_action(:list_addable, api: :public)
  end

  test "register_api still serves list_addable on operations" do
    register_operations_lists!
    document = RecordingStudioApi.openapi_document(version: "v1", api: :operations)
    catalog = RecordingStudioApi.documentation_catalog(version: "v1", api: :operations)
    registration = RecordingStudioApi.recordable_registration_for("RecordingStudio::Lists::List", api: :operations)
    action = RecordingStudioApi.capability_action(:list_addable, api: :operations)
    addable_paths = paths_named(document, "list_addable")

    assert_includes Array(registration.capability_actions).map(&:to_sym), :list_addable
    assert action.applicable_to?("RecordingStudio::Lists::List")
    refute action.applicable_to?("Page")
    assert_equal [ "List addable records" ], addable_paths.map { |path| path.fetch(:summary) }
    assert catalog_paths(catalog).any? { |path| path.include?("/actions/list_addable") }

    get "/recording_studio_api/apis/operations/v1/lists/#{@list.id}/actions/list_addable",
        headers: json_headers(issue_token(role: :view, api: :operations))
    assert_response :success
    addable_ids = response.parsed_body.fetch("records").map { |record| record.fetch("id") }
    assert_includes addable_ids, @page.id
    refute_includes addable_ids, @list.id

    get "/recording_studio_api/api/v1/lists/#{@list.id}/actions/list_addable", headers: json_headers(@edit_token)
    assert_response :unprocessable_entity
  end

  private

  def register_operations_lists!
    RecordingStudioApi.configuration.api(:operations)
    register_operations_workspace!
    RecordingStudioLists::Api.register_api(:operations)
  end

  def register_operations_workspace!
    return if RecordingStudioApi.recordable_registration_for("Workspace", api: :operations)

    RecordingStudioApi.register_recordable_type_api(
      "Workspace",
      api: :operations,
      operations: %i[show],
      serializer: ->(workspace, **) { { name: workspace.name } },
      output_keys: %i[name]
    )
  end

  def paths_named(document, action_name)
    document.fetch(:paths).filter_map do |path, operations|
      operation = operations["get"] || operations[:get]
      next unless path.include?(action_name) && operation

      { path: path, summary: operation[:summary] || operation["summary"] }
    end
  end

  def catalog_paths(catalog)
    catalog.fetch(:resources).flat_map { |section| section.fetch(:endpoints).map { |endpoint| endpoint.fetch(:path) } }
  end

  def assert_membership_titles(document)
    {
      ["/recording_studio_api/api/v1/lists/{id}/actions/list_add", "post"] => "Add to list",
      ["/recording_studio_api/api/v1/lists/{id}/actions/list_remove", "post"] => "Remove from list",
      ["/recording_studio_api/api/v1/lists/{id}/actions/list_items", "get"] => "List items"
    }.each do |(path, verb), title|
      operation = document.dig(:paths, path, verb)
      assert_equal title, operation.fetch(:summary)
      assert_equal title, operation.fetch(:title)
      assert_equal ["List"], operation.fetch(:tags)
    end
  end

  def assert_resource_titles(document)
    member = "/recording_studio_api/api/v1/lists/{id}"
    {
      ["/recording_studio_api/api/v1/lists", "get"] => "List lists",
      ["/recording_studio_api/api/v1/lists", "post"] => "Create a list",
      [member, "get"] => "Get a list",
      [member, "patch"] => "Update a list",
      [member, "delete"] => "Delete a list"
    }.each do |(path, verb), summary|
      operation = document.dig(:paths, path, verb)
      assert_equal summary, operation.fetch(:summary)
      assert_nil operation[:title]
      assert_equal ["List"], operation.fetch(:tags)
    end
  end

  def assert_no_type_first_list_copy(document)
    texts = []
    document.fetch(:paths).each do |path, operations|
      next unless path.include?("/lists")

      operations.each_value { |operation| collect_descriptions(operation, texts) }
      operations.each_value do |operation|
        texts << operation[:summary].to_s
        texts << operation[:title].to_s
        Array(operation[:tags]).each { |tag| texts << tag.to_s }
      end
    end
    document.fetch(:tags).each do |tag|
      texts << (tag[:name] || tag["name"]).to_s
      texts << (tag[:description] || tag["description"]).to_s
    end

    texts.each { |text| refute_includes text, "List - " }
  end

  def collect_descriptions(value, texts)
    case value
    when Hash
      value.each do |key, child|
        texts << child if key.to_s == "description" && child.is_a?(String)
        collect_descriptions(child, texts)
      end
    when Array
      value.each { |child| collect_descriptions(child, texts) }
    end
  end

  def json_headers(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def issue_token(role:, api: :public)
    result = RecordingStudioApi::Services::IssueTestCredential.call(
      api: api,
      actor: @user,
      access_point_recording: @root,
      role: role,
      name: "lists-api-#{role}-#{SecureRandom.hex(4)}"
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
