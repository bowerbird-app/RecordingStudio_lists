# frozen_string_literal: true

RecordingStudioOrderable.configure do |config|
  # Orderable 0.7 always asks Accessible for :edit before reorder, move, and append.
  # Lists membership add does not call those methods.
  config.log_order_events = true
  config.event_action = "reordered"
end
