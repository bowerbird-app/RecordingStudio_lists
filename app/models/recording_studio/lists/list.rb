# frozen_string_literal: true

module RecordingStudio
  module Lists
    class List < ActiveRecord::Base
      self.table_name = "recording_studio_lists"

      recording_studio_recordable label: "List", root: false

      include RecordingStudio::Capabilities::Orderable.to(
        allows: ["RecordingStudio::Lists::ListItem"]
      )

      validates :name, presence: true
    end
  end
end
