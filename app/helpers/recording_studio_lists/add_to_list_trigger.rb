# frozen_string_literal: true

module RecordingStudioLists
  # Keyword arguments for FlatPack::Button::Dropdown.
  # Defaults that older Flatpack rejects are left out.
  class AddToListTrigger
    def initialize(options)
      @options = options
    end

    def to_h
      text = label
      @options.slice(:icon, :style, :size, :placement).merge(
        text: text,
        trigger_attributes: attributes(text)
      ).tap { |trigger| assign_optional(trigger) }
    end

    private

    def label
      text = @options[:text]
      return text.to_s unless @options[:icon_only] && text.blank?

      RecordingStudio.t("recording_studio.lists.add_to_list.icon_only")
    end

    def attributes(text)
      attributes = { type: "button" }
      return attributes if text.present?

      attributes.merge(aria: { label: RecordingStudio.t("recording_studio.lists.add_to_list.trigger") })
    end

    def assign_optional(trigger)
      # Nil lets Dropdown choose. Passing nil before Flatpack 0.1.276 hides the chevron.
      trigger[:show_chevron] = @options[:show_chevron] unless @options[:show_chevron].nil?
      # false is the Dropdown default. Passing it raises unknown keyword before 0.1.276.
      trigger[:icon_only] = @options[:icon_only] unless @options[:icon_only] == false
      trigger[:round] = @options[:round] unless @options[:round] == false
    end
  end
end
