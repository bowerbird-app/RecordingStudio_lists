# frozen_string_literal: true

module RecordingStudio
  module Lists
    class List < ActiveRecord::Base
      self.table_name = "recording_studio_lists"

      LABEL = "List"

      # recording_studio_recordable captures label at class load; keep English here.
      recording_studio_recordable label: LABEL, root: false

      validates :name, presence: true

      def self.recordable_type_label
        RecordingStudioLists::Copy.t(
          "recordables.list.label",
          count: 1,
          default: LABEL
        )
      end

      class << self
        alias recording_studio_type_label recordable_type_label
      end
    end
  end
end
