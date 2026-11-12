# frozen_string_literal: true

require_relative "errors"

module RecordingStudioLists
  module Api
    module ListResource
      module_function

      def serialize(recording, context)
        ::RecordingStudioApi::Serializers::ResourceRecordingSerializer.call(
          recording,
          version: context.api_version,
          api: context.api_key
        )
      end

      def payload(context)
        ::RecordingStudioApi::RequestPayload.call(context)
      end

      def parent_recording(context)
        parent_id = context.parent_id.presence || payload(context)[:parent_id] || payload(context)["parent_id"]
        if parent_id.blank?
          raise ::RecordingStudioApi::InvalidActionInputError, "parent_id is required for #{Api::TYPE}"
        end

        parent = context.scoped_recordings.find_by(id: parent_id)
        raise ::RecordingStudioApi::NotFoundError, "Parent resource was not found in this API scope" if parent.nil?

        parent
      end

      def recording(context)
        recording = context.scoped_recordings.find_by(id: context.id, recordable_type: Api::TYPE)
        raise ::RecordingStudioApi::NotFoundError, "Resource was not found in this API scope" if recording.nil?

        RecordingStudio::Lists.find(recording.id)
      end

      def fields(context)
        raw = payload(context)
        symbolized = raw.respond_to?(:deep_symbolize_keys) ? raw.deep_symbolize_keys : raw.to_h.transform_keys(&:to_sym)
        symbolized.slice(*Api::WRITABLE_ATTRIBUTES)
      end

      class Index
        def self.call(context)
          Errors.wrap { new(context).payload }
        end

        def initialize(context)
          @context = context
        end

        def payload
          parent = ListResource.parent_recording(@context)
          @context.access_grant.authorize!(recording: parent, role: :view)
          pagination = ::RecordingStudioApi::Services::PaginateResourceCollection.call(**pagination_args(parent))
          raise ::RecordingStudioApi::InvalidPaginationTokenError, pagination.error if pagination.failure?

          { json: pagination.value.response_body { |recordings, meta| collection(recordings, meta) } }
        end

        def pagination_args(parent)
          {
            relation: RecordingStudio::Recording.unscoped.where(
              id: RecordingStudio::Lists.lists(parent).map(&:id)
            ),
            resource: @context.resource_name,
            recordable_type: @context.recordable_type,
            api: @context.api_key,
            scope_key: "client:#{@context.api_client.id}"
          }.merge(page_params)
        end

        def page_params
          params = @context.params
          {
            limit: params[:limit],
            pagination_token: params[:pagination_token],
            sort: params[:sort],
            order: params[:order],
            count: params[:count]
          }
        end

        def collection(recordings, meta)
          {
            resource: @context.resource_name,
            type: @context.recordable_type.demodulize,
            records: recordings.map { |recording| ListResource.serialize(recording, @context) },
            meta: meta
          }
        end
      end

      class Show
        def self.call(context)
          Errors.wrap do
            list = ListResource.recording(context)
            context.access_grant.authorize!(recording: list, role: :view)
            { json: ListResource.serialize(list, context) }
          end
        end
      end

      class Create
        def self.call(context)
          Errors.wrap { new(context).create }
        end

        def initialize(context)
          @context = context
        end

        def create
          parent = ListResource.parent_recording(@context)
          @context.access_grant.authorize!(recording: parent, role: :edit)
          list = RecordingStudio::Lists.create(**create_args(parent))
          { json: ListResource.serialize(list, @context), status: :created }
        end

        def create_args(parent)
          fields = ListResource.fields(@context)
          {
            parent:, name: fields[:name], description: fields[:description],
            actor: @context.actor, idempotency_key: @context.idempotency_key
          }
        end
      end

      class Update
        def self.call(context)
          Errors.wrap { new(context).update }
        end

        def initialize(context)
          @context = context
        end

        def update
          list = ListResource.recording(@context)
          @context.access_grant.authorize!(recording: list, role: :edit)
          fields = ListResource.fields(@context)
          updated = RecordingStudio::Lists.update(
            list, name: fields[:name], description: fields[:description], actor: @context.actor
          )
          { json: ListResource.serialize(updated, @context) }
        end
      end

      class Destroy
        def self.call(context)
          Errors.wrap do
            list = ListResource.recording(context)
            context.access_grant.authorize!(recording: list, role: :edit)
            serialized = ListResource.serialize(list, context)
            RecordingStudio::Lists.delete(list)
            { json: serialized.merge(deleted: true, deleted_via: "destroyed") }
          end
        end
      end
    end
  end
end
