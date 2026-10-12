# frozen_string_literal: true

require "i18n"

module RecordingStudioLists
  module Copy
    PREFIX = "recording_studio.lists"

    module_function

    def t(key, **)
      I18n.t("#{PREFIX}.#{key}", **)
    end
  end
end
