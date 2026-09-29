# frozen_string_literal: true

module RecordingStudioLists
  module ListsHelper
    def lists_nav_right
      recording_studio_page_nav_right do
        if respond_to?(:recording_studio_root_switch_dropdown)
          concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
        end

        concat render(FlatPack::Button::Component.new(text: "Lists", style: :ghost, size: :md, href: lists_path))

        if main_app.respond_to?(:destroy_user_session_path)
          concat render(
            FlatPack::Button::Component.new(
              text: "Sign out",
              style: :ghost,
              size: :md,
              href: main_app.destroy_user_session_path,
              method: :delete
            )
          )
        end
      end
    end
  end
end
