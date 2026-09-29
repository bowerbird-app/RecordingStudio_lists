# frozen_string_literal: true

module RecordingStudioLists
  module AddToListHelper
    def recording_studio_add_to_list(
      recording,
      text: "Add to list",
      icon: nil,
      style: :default,
      size: :md,
      placement: :bottom_left,
      parent: nil,
      return_to: nil
    )
      target = add_to_list_recording(recording)
      place = add_to_list_parent(parent)
      return if target.nil? || place.nil?

      lists = RecordingStudio::Lists.lists(place)
      return_path = add_to_list_return_path(return_to)
      render(
        "recording_studio_lists/add_to_list",
        text: text.presence || "Add to list",
        icon: icon,
        style: style,
        size: size,
        placement: placement,
        rows: add_to_list_rows(lists, target),
        new_list_href: add_to_list_new_href(target, return_path),
        recording_id: target.id,
        return_to: return_path
      )
    rescue RecordingStudio::Lists::Error
      nil
    end

    private

    def add_to_list_recording(recording)
      return recording if recording.is_a?(RecordingStudio::Recording) && recording.persisted?
      return if recording.blank?

      RecordingStudio::Recording.find_by(id: recording)
    end

    def add_to_list_parent(parent)
      return parent if parent.present?
      return current_root_recording if respond_to?(:current_root_recording)

      nil
    end

    def add_to_list_return_path(return_to)
      candidate = return_to.presence || request&.fullpath
      RecordingStudio::Lists::InternalPath.sanitize(candidate)
    end

    def add_to_list_rows(lists, recording)
      sequence = next_add_to_list_sequence
      member_ids = add_to_list_member_ids(lists, recording)
      lists.map do |list|
        {
          name: list.name.to_s,
          url: recording_studio_lists.items_list_path(list),
          form_id: "add-to-list-#{sequence}-#{list.id}",
          member: member_ids.include?(list.id.to_s)
        }
      end
    end

    # One lookup for every list under this parent that already holds the recording.
    def add_to_list_member_ids(lists, recording)
      ids = lists.map(&:id)
      return Set.new if ids.empty?

      RecordingStudio::Recording
        .joins("INNER JOIN recording_studio_list_items ON recording_studio_list_items.id = recording_studio_recordings.recordable_id")
        .where(parent_recording_id: ids, recordable_type: RecordingStudio::Lists::ITEM_TYPE)
        .where(recording_studio_list_items: { item_recording_id: recording.id })
        .distinct
        .pluck(:parent_recording_id)
        .to_set(&:to_s)
    end

    def add_to_list_new_href(recording, return_path)
      query = { recording_id: recording.id }
      query[:return_to] = return_path if return_path.present?
      recording_studio_lists.new_list_path(query)
    end

    def next_add_to_list_sequence
      @recording_studio_add_to_list_sequence = @recording_studio_add_to_list_sequence.to_i + 1
    end
  end
end
