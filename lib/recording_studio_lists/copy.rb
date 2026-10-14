# frozen_string_literal: true

module RecordingStudioLists
  # Locale lookups for lists user-facing copy. Relative keys resolve under
  # `recording_studio.lists` through {RecordingStudio.t} so a missing
  # active-locale value falls back to loaded English (host overrides included),
  # then the caller's `default:`, then the gem-shipped en.yml table registered
  # via {RecordingStudio::Translation.register_shipped_english}.
  module Copy
    PREFIX = "recording_studio.lists"

    module_function

    def t(key, **)
      RecordingStudio.t("#{PREFIX}.#{key}", **)
    end
  end
end
