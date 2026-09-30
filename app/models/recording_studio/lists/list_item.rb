# frozen_string_literal: true

module RecordingStudio
  module Lists
    class ListItem < ActiveRecord::Base
      self.table_name = "recording_studio_list_items"

      recording_studio_recordable label: "List item", plural_label: "List items", root: false,
                                  allowed_parent_types: ["RecordingStudio::Lists::List"]

      validates :item_recording_id, :position, presence: true
      belongs_to :item_recording, class_name: "RecordingStudio::Recording"
    end
  end
end
