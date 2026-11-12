# frozen_string_literal: true

require_relative "errors"

module RecordingStudioLists
  module Api
    module MembershipActions
      module_function

      def register!(api)
        register_add(api)
        register_remove(api)
        register_items(api)
        register_addable(api)
      end

      def register_add(api)
        register_action(name: :add, api:, handler: Add, required_role: :edit,
                        input_contract: recording_id_contract, docs: add_docs)
      end

      def register_remove(api)
        register_action(name: :remove, api:, handler: Remove, required_role: :edit,
                        input_contract: recording_id_contract, docs: remove_docs)
      end

      def register_items(api)
        register_action(name: :items, api:, handler: Items, required_role: :view,
                        input_contract: empty_contract, docs: items_docs)
      end

      def register_addable(api)
        register_action(name: :addable, api:, handler: Addable, required_role: :view,
                        input_contract: empty_contract, docs: addable_docs)
      end

      def register_action(name:, **options)
        return if ::RecordingStudioApi.capability_action(name, api: options[:api])

        ::RecordingStudioApi.register_capability_action(name, **action_options(**options))
      end

      def action_options(api:, handler:, required_role:, input_contract:, docs:)
        {
          capability: :lists, version: "1.0.0", http_verb: http_verb_for(handler), required_role:,
          handler:, input_contract:, serializer: serializer_for(handler),
          openapi: docs, api:
        }
      end

      def add_docs
        {
          title: "List - Add",
          summary: "List - Add",
          description: "Adds a recording to this list. The list must be editable. The target must " \
                       "exist in the same workspace, must not be this list, and must not already " \
                       "be a list item."
        }
      end

      def remove_docs
        {
          title: "List - Remove",
          summary: "List - Remove",
          description: "Removes a recording from this list. The list must be editable. The target " \
                       "must exist. The list row is locked while membership is removed."
        }
      end

      def items_docs
        {
          title: "List - Items",
          summary: "List - Items",
          description: "Returns the recordings on this list, in list order. The list must be viewable."
        }
      end

      def addable_docs
        {
          title: "List - Addable",
          summary: "List - Addable",
          description: "Returns recordings in this workspace that can still be added to the list. " \
                       "Skips the list itself, list items, other lists, and recordings already on it."
        }
      end

      def http_verb_for(handler)
        [Items, Addable].include?(handler) ? :get : :post
      end

      def serializer_for(handler)
        return method(:serialize_recordings) if [Items, Addable].include?(handler)

        nil
      end

      def serialize_recordings(recordings, **)
        { records: Array(recordings).map { |recording| { id: recording.id, type: recording.recordable_type } } }
      end

      def recording_id_contract
        {
          reject_unknown: false,
          fields: { recording_id: { type: :string, required: true, allow_blank: false } }
        }
      end

      def empty_contract
        { reject_unknown: false, fields: {} }
      end

      class Add
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :edit)
            RecordingStudio::Lists.add(context.recording, context.params[:recording_id], actor: context.actor)
            context.recording
          end
        end
      end

      class Remove
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :edit)
            RecordingStudio::Lists.remove(context.recording, context.params[:recording_id])
            context.recording
          end
        end
      end

      class Items
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :view)
            RecordingStudio::Lists.items(context.recording)
          end
        end
      end

      class Addable
        def self.call(context)
          Errors.wrap do
            context.access_grant.authorize!(recording: context.recording, role: :view)
            RecordingStudio::Lists.addable(context.recording)
          end
        end
      end
    end
  end
end
