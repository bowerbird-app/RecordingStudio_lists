# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User" ]
  config.access_actor_types += ["RecordingStudioApi::ApiClient"]

  # Accessible 0.45 denies mounted pages unless this returns the admin root.
  config.admin_root_resolver = lambda do
    workspace = Workspace.find_by(name: "Studio Workspace")
    next unless workspace

    RecordingStudio.root_recording_for(workspace)
  end
end
