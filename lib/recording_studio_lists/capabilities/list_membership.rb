# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    module ListMembership
      def self.to(**)
        RecordingStudio::Capabilities.include_for(:list_membership, **)
      end
    end
  end
end

RecordingStudio.register_capability(
  :list_membership,
  source: "recording_studio_lists"
)
