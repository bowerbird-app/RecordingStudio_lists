# frozen_string_literal: true

module RecordingStudioLists
  module AddToListAccess
    private

    def add_to_list_accessible_lists(place)
      AccessibleLists.for(actor: add_to_list_actor, parent: place, minimum_role: :edit)
    end

    def add_to_list_actor
      Current.actor if defined?(Current)
    end
  end
end
