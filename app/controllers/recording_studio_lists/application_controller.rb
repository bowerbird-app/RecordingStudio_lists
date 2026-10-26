# frozen_string_literal: true

module RecordingStudioLists
  def self.host_application_controller
    Object.const_get(:ApplicationController)
  rescue NameError
    ActionController::Base
  end

  class ApplicationController < RecordingStudioLists.host_application_controller
    recording_studio_layout { RecordingStudioLists.configuration.layout }
  end
end
