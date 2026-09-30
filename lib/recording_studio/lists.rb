# frozen_string_literal: true

module RecordingStudio
  module Lists
    LIST_TYPE = "RecordingStudio::Lists::List"
    ITEM_TYPE = "RecordingStudio::Lists::ListItem"

    class Error < StandardError; end

    class BlankName < Error
      def initialize(message = "Name can't be blank.")
        super
      end
    end

    class InvalidList < Error
      def initialize(message = "That list is missing.")
        super
      end
    end

    class MissingTarget < Error
      def initialize(message = "Pick something to add.")
        super
      end
    end

    class DifferentRoot < Error
      def initialize(message = "That lives somewhere else.")
        super
      end
    end

    class SelfTarget < Error
      def initialize(message = "A list can't contain itself.")
        super
      end
    end

    class ListItemTarget < Error
      def initialize(message = "That can't go on a list.")
        super
      end
    end

    class ParentNotAllowed < Error
      def initialize(message = "Lists can't be created here.")
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
