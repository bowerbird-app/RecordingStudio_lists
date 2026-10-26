# frozen_string_literal: true

module RecordingStudioLists
  module ListMemberHrefHelper
    def list_member_href(item)
      return if item.nil?

      path_for(item.recordable) || path_for(item)
    end

    private

    def path_for(record)
      return if record.nil?

      main_app.polymorphic_path(record)
    rescue ActionController::UrlGenerationError, NoMethodError, ArgumentError
      nil
    end
  end
end
