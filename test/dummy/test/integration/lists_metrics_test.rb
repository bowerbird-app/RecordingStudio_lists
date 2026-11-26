# frozen_string_literal: true

require "test_helper"

class ListsMetricsTest < ActionDispatch::IntegrationTest
  OPERATIONS_METRICS = "/recording_studio_api/apis/operations/v1/metrics"

  setup do
    @user = User.create!(
      email: "lists-metrics-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    @root = RecordingStudio.create_root_recording!(
      Workspace.create!(name: "Lists metrics #{SecureRandom.hex(4)}"),
      actor: @user
    )
    grant_owner_access!(actor: @user, recording: @root)
  end

  test "lists and list item totals count only those recordings" do
    skip "recording_studio_metrics is optional" unless RecordingStudioLists::Metrics.metrics_available?

    RecordingStudioLists::Metrics.register! unless RecordingStudioMetrics.find("lists.total")
    lists_before = metric_value("lists.total")
    items_before = metric_value("list_items.total")
    lists_over_time_before = series_total("lists.over_time")

    record_page(@root, "Not a list")
    assert_equal lists_before, metric_value("lists.total")
    assert_equal items_before, metric_value("list_items.total")

    list = RecordingStudio::Lists.create(parent: @root, name: "Shelf", actor: @user)
    assert_equal lists_before + 1, metric_value("lists.total")
    assert_equal items_before, metric_value("list_items.total")
    assert_equal lists_over_time_before + 1, series_total("lists.over_time")

    page = record_page(@root, "Member")
    RecordingStudio::Lists.add(list, page, actor: @user)
    assert_equal lists_before + 1, metric_value("lists.total")
    assert_equal items_before + 1, metric_value("list_items.total")
    assert_equal :created_at, RecordingStudioMetrics.find("list_items.over_time").field
    assert_catalog_names
  end

  test "operations metrics deny a workspace token and allow a staff token" do
    skip "recording_studio_metrics is optional" unless RecordingStudioLists::Metrics.metrics_available?
    skip "recording_studio_admin is optional" unless defined?(::RecordingStudioAdmin)

    RecordingStudioLists::Metrics.register! unless RecordingStudioMetrics.find("lists.total")
    ensure_operations_metrics_api!
    register_operations_workspace!

    other = User.create!(
      email: "lists-metrics-other-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    other_root = RecordingStudio.create_root_recording!(
      Workspace.create!(name: "Lists metrics other #{SecureRandom.hex(4)}"),
      actor: other
    )
    grant_owner_access!(actor: other, recording: other_root)
    RecordingStudio::Lists.create(parent: @root, name: "Alpha shelf", actor: @user)
    RecordingStudio::Lists.create(parent: other_root, name: "Beta shelf", actor: other)

    workspace_token = issue_token(actor: @user, recording: @root, role: :view, api: :operations)
    get "#{OPERATIONS_METRICS}/lists/total", headers: json_headers(workspace_token)
    assert_response :forbidden

    staff = User.create!(
      email: "lists-metrics-staff-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    admin_root = staff_admin_root(staff)
    staff_token = issue_token(actor: staff, recording: admin_root, role: :view, api: :operations)
    get "#{OPERATIONS_METRICS}/lists/total", headers: json_headers(staff_token)
    assert_response :success
    assert_operator response.parsed_body.fetch("value").to_i, :>=, 2
  end

  private

  def metric_value(identifier)
    RecordingStudioMetrics.execute(identifier, context: site_context, cache: false).value
  end

  def series_total(identifier)
    result = RecordingStudioMetrics.execute(
      identifier,
      context: site_context,
      cache: false,
      interval: :day,
      start_at: Time.current.beginning_of_day,
      end_at: Time.current.end_of_day + 1.second
    )
    Array(result.data).sum { |row| row.fetch(:value).to_i }
  end

  def site_context
    RecordingStudioMetrics::Context.new(actor: @user, scope: :site, site_authorized: true)
  end

  def assert_catalog_names
    expected = RecordingStudioLists::McpCopy::METRIC_TOOL_NAMES
    assert_equal expected, RecordingStudioLists::McpCopy.tool_names.fetch(:operations)

    {
      "lists.total" => [ "lists-total", "RecordingStudio::Lists::List" ],
      "list_items.total" => [ "list_items-total", "RecordingStudio::Lists::ListItem" ],
      "lists.over_time" => [ "lists-over_time", "RecordingStudio::Lists::List" ],
      "list_items.over_time" => [ "list_items-over_time", "RecordingStudio::Lists::ListItem" ]
    }.each do |identifier, (catalog_name, recordable_type)|
      definition = RecordingStudioMetrics.find(identifier)
      assert definition, identifier
      assert_equal catalog_name, definition.identifier.sub(".", "-")
      assert_equal RecordingStudio::Recording, definition.model
      assert_equal :site, definition.blast_radius
      assert definition.exposed_to_api?(:operations)
      refute definition.exposed_to_api?(:public)
      assert_equal({ recordable_type: recordable_type }, scoped_where(definition))
      refute_includes RecordingStudioLists::McpCopy.tool_names.fetch(:public), catalog_name
      assert_includes expected, catalog_name
    end
  end

  def scoped_where(definition)
    relation = Object.new
    captured = nil
    relation.define_singleton_method(:where) do |**conditions|
      captured = conditions
      :scoped
    end
    assert_equal :scoped, definition.scope.call(relation)
    captured
  end

  def ensure_operations_metrics_api!
    RecordingStudioApi.configuration.api(:operations)
    RecordingStudioMetrics::Api.register!(api: :operations)
  rescue RecordingStudioApi::ConfigurationError
    nil
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

  def staff_admin_root(staff)
    workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    recording = RecordingStudio.root_recording_for(workspace) ||
                RecordingStudio.create_root_recording!(workspace, actor: staff)
    grant_owner_access!(actor: staff, recording: recording)
    recording
  end

  def issue_token(actor:, recording:, role:, api:)
    result = RecordingStudioApi::Services::IssueTestCredential.call(
      api: api,
      actor: actor,
      access_point_recording: recording,
      role: role,
      name: "lists-metrics-#{role}-#{SecureRandom.hex(4)}"
    )
    raise result.error if result.failure?

    api_client = result.value.fetch(:api_client)
    api_client.update!(owner: actor) if api_client.owner != actor

    result.value.fetch(:access_token)
  end

  def json_headers(token)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
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
end
