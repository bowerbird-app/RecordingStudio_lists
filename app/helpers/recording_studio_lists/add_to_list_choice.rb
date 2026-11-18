# frozen_string_literal: true

module RecordingStudioLists
  class AddToListChoice
    def self.html(view, row)
      new(view, row).html
    end

    def initialize(view, row)
      @view = view
      @row = row
    end

    def html
      item = FlatPack::Button::DropdownItem::Component.new(
        text: @row[:name],
        icon: "check",
        icon_position: :end,
        keep_open: true,
        form: @row[:form_id],
        type: "button"
      )
      item.plain_actions = true
      mark(@view.render(item))
    end

    private

    def mark(html)
      marker = "data-recording-studio-lists--add-to-list-target=\"check\""
      marker = "hidden #{marker}" unless @row[:member]
      html.sub("<svg", "<svg #{marker}").html_safe
    end
  end
end
