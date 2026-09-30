# frozen_string_literal: true

module RecordingStudioLists
  def self.host_application_controller
    Object.const_get(:ApplicationController)
  rescue NameError
    ActionController::Base
  end

  class ApplicationController < RecordingStudioLists.host_application_controller
    include RecordingStudio::UsesDefaultLayout unless included_modules.include?(RecordingStudio::UsesDefaultLayout)

    helper RecordingStudio::LayoutHelper
  end
end
