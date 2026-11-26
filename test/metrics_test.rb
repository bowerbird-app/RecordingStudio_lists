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

  def test_authorize_denies_when_admin_is_not_loaded
    refute defined?(::RecordingStudioAdmin)
    refute RecordingStudioLists::Metrics::AUTHORIZE.call(Object.new)
  end

  def test_gemspec_does_not_depend_on_recording_studio_metrics
    gemspec = File.read(File.expand_path("../recording_studio_lists.gemspec", __dir__))
    entry = File.read(File.expand_path("../lib/recording_studio_lists.rb", __dir__))

    refute_includes gemspec, "recording_studio_metrics"
    refute_includes entry, 'require "recording_studio_metrics"'
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
