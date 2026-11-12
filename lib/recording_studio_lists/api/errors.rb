# frozen_string_literal: true

module RecordingStudioLists
  module Api
    module Errors
      module_function

      def wrap
        yield
      rescue RecordingStudio::Lists::InvalidList => e
        raise ::RecordingStudioApi::NotFoundError, e.message
      rescue RecordingStudio::Lists::BlankName, RecordingStudio::Lists::MissingTarget,
             RecordingStudio::Lists::DifferentRoot, RecordingStudio::Lists::SelfTarget,
             RecordingStudio::Lists::ListItemTarget, RecordingStudio::Lists::ParentNotAllowed => e
        raise ::RecordingStudioApi::InvalidActionInputError, e.message
      end
    end
  end
end
