# frozen_string_literal: true

module RecordingStudio
  module Lists
    class ListItem < ActiveRecord::Base
      self.table_name = "recording_studio_list_items"

      LABEL = "List item"
      PLURAL_LABEL = "List items"

      # recording_studio_recordable captures label at class load; keep English here.
      recording_studio_recordable label: LABEL, plural_label: PLURAL_LABEL, root: false,
                                  allowed_parent_types: ["RecordingStudio::Lists::List"]

      validates :item_recording_id, :position, presence: true
      belongs_to :item_recording, class_name: "RecordingStudio::Recording"

      def self.recordable_type_label
        RecordingStudioLists::Copy.t(
          "recordables.list_item.label",
          count: 1,
          default: LABEL
        )
      end

      def self.recordable_type_plural_label
        RecordingStudioLists::Copy.t(
          "recordables.list_item.label",
          count: 2,
          default: PLURAL_LABEL
        )
      end

      class << self
        alias recording_studio_type_label recordable_type_label
      end
    end
  end
end
