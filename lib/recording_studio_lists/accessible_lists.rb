# frozen_string_literal: true

module RecordingStudioLists
  module AccessibleLists
    def self.for(actor:, parent:, minimum_role:)
      return [] unless actor && parent&.persisted?

      ids = RecordingStudioAccessible.recording_ids_for(
        actor: actor, parent_recording: parent, minimum_role: minimum_role,
        recordable_type: RecordingStudio::Lists::List
      )
      parent.child_recordings.where(recordable_type: RecordingStudio::Lists::LIST_TYPE, id: ids)
            .includes(:recordable).to_a
            .sort_by { |recording| [recording.recordable.name.to_s, recording.id.to_s] }
    end
  end
end
