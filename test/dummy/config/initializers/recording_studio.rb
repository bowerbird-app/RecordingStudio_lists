# frozen_string_literal: true

RecordingStudio.configure do |config|
  # Registered delegated_type recordables (strings or classes)
  config.recordable_types = ["Workspace", "Folder", "Page", "RecordingStudio::Lists::List", "RecordingStudio::Lists::ListItem"]
  if defined?(RecordingStudioApi)
    # recording_studio_api.rb loads later and sets the same empty list. Clear it
    # first so AdminApi is not registered against the default AdminRoot name.
    RecordingStudioApi.configuration.admin_root_recordable_type_names = []
    config.recordable_types += [
      "RecordingStudio::Access",
      "RecordingStudioApi::ApiClient",
      "RecordingStudioApi::ApiCredential",
      "RecordingStudioApi::ApiAccessToken"
    ]
    if RecordingStudioApi.configuration.admin_root_recordable_type_names.present?
      config.recordable_types << "RecordingStudioApi::AdminApi"
    end
  end

  # Require each configured ActiveRecord type to call recording_studio_recordable.
  config.require_recordable_declarations = true

  # Recording Studio denies a write when authorize_write is unset.
  # A present actor may write, including a root create where root_recording is nil.
  config.authorize_write = ->(actor:, **) { actor.present? }

  # Shown in the shared default layout title fallback.
  config.app_name = "Lists" if config.respond_to?(:app_name=)

  # Actor resolver for events when no actor is explicitly supplied
  config.actor = -> { Current.actor }

  # Emit ActiveSupport::Notifications events
  config.event_notifications_enabled = true

  # Idempotency behavior for log_event!
  config.idempotency_mode = :return_existing # or :raise

  # Recordable duplication strategy for revisions
  config.recordable_dup_strategy = :dup
end
