# frozen_string_literal: true

require "test_helper"

class ListsMetricsTest < ActionDispatch::IntegrationTest
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

  test "metric authorize follows accessible view on the access recording" do
    skip "recording_studio_metrics is optional" unless RecordingStudioLists::Metrics.metrics_available?

    blank = Struct.new(:actor, :access_recording).new(nil, nil)
    refute RecordingStudioLists::Metrics::AUTHORIZE.call(blank)
    refute RecordingStudioLists::Metrics::AUTHORIZE.call(Struct.new(:actor, :access_recording).new(@user, nil))
    assert RecordingStudioLists::Metrics::AUTHORIZE.call(
      Struct.new(:actor, :access_recording).new(@user, @root)
    )

    endpoint = Struct.new(:access_grant, :access_recording).new(Struct.new(:actor).new(@user), @root)
    assert RecordingStudioLists::Metrics::AUTHORIZE.call(endpoint)

    stranger = User.create!(
      email: "lists-metrics-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "ListsTestPassword!2026",
      password_confirmation: "ListsTestPassword!2026"
    )
    refute RecordingStudioLists::Metrics::AUTHORIZE.call(
      Struct.new(:access_grant, :access_recording).new(Struct.new(:actor).new(stranger), @root)
    )
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
      refute_includes RecordingStudioLists::McpCopy.tool_names.fetch(:operations), catalog_name
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
