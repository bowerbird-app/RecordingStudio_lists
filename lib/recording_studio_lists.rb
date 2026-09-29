# frozen_string_literal: true

require "recording_studio"
require "recording_studio_lists/version"
require "recording_studio_lists/engine"
require "recording_studio_lists/configuration"
require "recording_studio_lists/capabilities/example"
require "recording_studio/lists"

module RecordingStudioLists
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end
  end
end
