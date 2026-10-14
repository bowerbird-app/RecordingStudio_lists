# frozen_string_literal: true

RecordingStudioOrderable.configure do |config|
  # Lists membership does not require Orderable's Accessible edit check; the
  # host (or lists controller) already decided the actor may change the list.
  config.use_recording_studio_accessible = false
  config.log_order_events = true
  config.event_action = "reordered"
end
