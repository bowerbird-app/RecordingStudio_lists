# frozen_string_literal: true

require "test_helper"

class MetricsTest < Minitest::Test
  FORBIDDEN = [
    "RecordingStudio::", "Access", "Accessible", ":edit", ":view", "permission", "role",
    "Admin", "staff", "operations"
  ].freeze

  def test_register_is_a_no_op_when_metrics_is_not_loaded
    RecordingStudioLists::Metrics.stub(:metrics_available?, false) do
      assert_nil RecordingStudioLists::Metrics.register!
    end
  end

  def test_authorize_uses_accessible_view_on_the_access_recording
    actor = Object.new
    recording = Object.new
    seen = nil
    check = lambda do |**kwargs|
      seen = kwargs
      true
    end

    RecordingStudioAccessible.stub(:authorized?, check) do
      assert RecordingStudioLists::Metrics::AUTHORIZE.call(
        Struct.new(:actor, :access_recording).new(actor, recording)
      )
      endpoint = Struct.new(:access_grant, :access_recording).new(Struct.new(:actor).new(actor), recording)
      assert RecordingStudioLists::Metrics::AUTHORIZE.call(endpoint)
    end

    assert_equal({ actor: actor, recording: recording, role: :view }, seen)
    refute RecordingStudioLists::Metrics::AUTHORIZE.call(nil)
    refute RecordingStudioLists::Metrics::AUTHORIZE.call(Struct.new(:actor, :access_recording).new(nil, recording))
    refute RecordingStudioLists::Metrics::AUTHORIZE.call(Struct.new(:actor, :access_recording).new(actor, nil))

    RecordingStudioAccessible.stub(:authorized?, ->(**) { false }) do
      refute RecordingStudioLists::Metrics::AUTHORIZE.call(
        Struct.new(:actor, :access_recording).new(actor, recording)
      )
    end
  end

  def test_gemspec_does_not_depend_on_recording_studio_metrics
    gemspec = File.read(File.expand_path("../recording_studio_lists.gemspec", __dir__))
    entry = File.read(File.expand_path("../lib/recording_studio_lists.rb", __dir__))
    metrics = File.read(File.expand_path("../lib/recording_studio_lists/metrics.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_lists/engine.rb", __dir__))

    refute_includes gemspec, "recording_studio_metrics"
    refute_includes entry, 'require "recording_studio_metrics"'
    refute_includes metrics, 'require "recording_studio_metrics"'
    refute_includes metrics, "rescue"
    refute_includes metrics, "RecordingStudioMetrics::Api.register!"
    refute_includes metrics, "register_tool"
    assert_includes engine, 'require_relative "metrics"'
    assert_includes engine, "Metrics.register! if defined?(::RecordingStudioMetrics)"
    assert_includes metrics, "RecordingStudioMetrics.register"
    assert_includes metrics, ":lists"
    assert_includes metrics, ":list_items"
    assert_includes metrics, "count :total"
    assert_includes metrics, "timeseries :over_time"
    assert_includes metrics, "field: :created_at"
    assert_includes metrics, "blast_radius: :site"
    assert_includes metrics, "RecordingStudioAccessible.authorized?"
    refute_includes engine, "RecordingStudioMetrics::Api.register!"
  end

  def test_metric_copy_is_safe_for_catalog_tools
    copy = [
      RecordingStudioLists::Metrics::LISTS_TOTAL,
      RecordingStudioLists::Metrics::LIST_ITEMS_TOTAL,
      RecordingStudioLists::Metrics::LISTS_OVER_TIME,
      RecordingStudioLists::Metrics::LIST_ITEMS_OVER_TIME
    ]

    copy.each do |phrase|
      FORBIDDEN.each { |word| refute_includes phrase, word }
    end
  end
end
