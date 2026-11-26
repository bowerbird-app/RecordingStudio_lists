# frozen_string_literal: true

return unless defined?(RecordingStudioAdmin)

RecordingStudioAdmin.configure do |config|
  config.access_recording_resolver = lambda do |_context|
    RecordingStudioAccessible.admin_root
  end
end
