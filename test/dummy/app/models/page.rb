class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false, allowed_parent_types: [ "Workspace", "Folder" ]
  # Exists for the list_membership leak test.
  RecordingStudio.enable_capability(:orderable, on: self)
end
