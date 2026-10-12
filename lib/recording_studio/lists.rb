# frozen_string_literal: true

module RecordingStudio
  module Lists
    LIST_TYPE = "RecordingStudio::Lists::List"
    ITEM_TYPE = "RecordingStudio::Lists::ListItem"

    class Error < StandardError; end

    class BlankName < Error
      MESSAGE = "Name can't be blank."

      def initialize(message = MESSAGE)
        super
      end
    end

    class InvalidList < Error
      MESSAGE = "That list is missing."

      def initialize(message = MESSAGE)
        super
      end
    end

    class MissingTarget < Error
      MESSAGE = "Pick something to add."

      def initialize(message = MESSAGE)
        super
      end
    end

    class DifferentRoot < Error
      MESSAGE = "That lives somewhere else."

      def initialize(message = MESSAGE)
        super
      end
    end

    class SelfTarget < Error
      MESSAGE = "A list can't contain itself."

      def initialize(message = MESSAGE)
        super
      end
    end

    class ListItemTarget < Error
      MESSAGE = "That can't go on a list."

      def initialize(message = MESSAGE)
        super
      end
    end

    class ParentNotAllowed < Error
      MESSAGE = "Lists can't be created here."

      def initialize(message = MESSAGE)
        super
      end
    end

    # Raised when the lists controller has no current root/place. Distinct from
    # ParentNotAllowed so render sites can translate without comparing message
    # strings. Hosts that rescue ParentNotAllowed still catch this.
    class ChoosePlace < ParentNotAllowed
      MESSAGE = "Choose a place for this list first."

      def initialize(message = MESSAGE)
        super
      end
    end

    def self.create(parent:, name:, description: nil, idempotency_key: nil, actor: nil)
      Services::Create.call(parent:, name:, description:, idempotency_key:, actor:).value!
    end

    def self.add(list, target, actor: nil)
      Services::Add.call(list:, target:, actor:).value!
    end

    def self.remove(list, target)
      Services::Remove.call(list:, target:).value!
    end

    def self.items(list)
      Services::Items.call(list:).value!
    end

    def self.lists(parent)
      Services::Lists.call(parent:).value!
    end

    def self.find(id)
      Services::Find.call(id:).value!
    end

    def self.addable(list)
      Services::Addable.call(list:).value!
    end

    def self.delete(list)
      Services::Delete.call(list:).value!
    end
  end
end

require "recording_studio/lists/internal_path"
require "recording_studio/lists/services"

RecordingStudio.register_capability(
  :lists,
  source: "recording_studio_lists",
  child_recordables: ["RecordingStudio::Lists::List"]
)
