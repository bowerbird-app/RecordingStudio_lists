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

  test "lists and list item totals count current recordings" do
    skip "recording_studio_metrics is optional" unless RecordingStudioLists::Metrics.metrics_available?

    RecordingStudioLists::Metrics.register! unless RecordingStudioMetrics.find("lists.total")
    list = RecordingStudio::Lists.create(parent: @root, name: "Shelf", actor: @user)
    page = record_page(@root, "Member")
    RecordingStudio::Lists.add(list, page, actor: @user)

    context = RecordingStudioMetrics::Context.new(actor: @user, scope: :site, site_authorized: true)
    lists = RecordingStudioMetrics.execute("lists.total", context: context)
    items = RecordingStudioMetrics.execute("list_items.total", context: context)

    assert_operator lists.value, :>=, 1
    assert_operator items.value, :>=, 1
    assert RecordingStudioMetrics.find("lists.over_time")
    assert RecordingStudioMetrics.find("list_items.over_time")
    assert RecordingStudioMetrics.find("lists.total").exposed_to_api?(:operations)
    assert RecordingStudioMetrics.find("list_items.total").exposed_to_api?(:operations)
  end

  test "metric authorize is false without an actor or recording" do
    skip "recording_studio_metrics is optional" unless RecordingStudioLists::Metrics.metrics_available?

    blank = Struct.new(:actor, :access_recording).new(nil, nil)
    refute RecordingStudioLists::Metrics::AUTHORIZE.call(blank)
    refute RecordingStudioLists::Metrics::AUTHORIZE.call(Struct.new(:actor, :access_recording).new(@user, nil))
    assert RecordingStudioLists::Metrics::AUTHORIZE.call(
      Struct.new(:actor, :access_recording).new(@user, @root)
    )
  end

  private

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
