# frozen_string_literal: true

require_relative "api/list_resource"
require_relative "api/membership_actions"

module RecordingStudioLists
  module Api
    TYPE = "RecordingStudio::Lists::List"
    CAPABILITY_ACTIONS = %i[add remove items addable].freeze
    OUTPUT_KEYS = %i[name description].freeze
    WRITABLE_ATTRIBUTES = %i[name description].freeze

    module_function

    def register!
      return unless defined?(::RecordingStudioApi)

      ::RecordingStudioApi.configuration.each_api { |api| register_api(api.name) }
    end

    def register_api(api)
      register_type(api)
      register_resource_handlers(api)
      MembershipActions.register!(api)
    end

    def register_type(api)
      return if ::RecordingStudioApi.recordable_registration_for(TYPE, api:)

      ::RecordingStudioApi.register_recordable_type_api(TYPE, **type_options(api))
    end

    def type_options(api)
      type_behavior.merge(api:, serializer: method(:serialize_fields), openapi: type_openapi)
    end

    def type_behavior
      {
        operations: %i[index show create update destroy],
        auto_capability_actions: false,
        capability_actions: CAPABILITY_ACTIONS,
        output_keys: OUTPUT_KEYS,
        writable_attributes: WRITABLE_ATTRIBUTES
      }
    end

    def type_openapi
      {
        tags: ["Lists"],
        description: "Named lists of recordings. Index, show, create, update, and delete wrap " \
                     "RecordingStudio::Lists.lists, RecordingStudio::Lists.find, " \
                     "RecordingStudio::Lists.create, RecordingStudio::Lists.update, and " \
                     "RecordingStudio::Lists.delete."
      }
    end

    def register_resource_handlers(api)
      {
        index: ListResource::Index,
        show: ListResource::Show,
        create: ListResource::Create,
        update: ListResource::Update,
        destroy: ListResource::Destroy
      }.each do |action, handler|
        next if ::RecordingStudioApi.resource_handler(TYPE, action, api:)

        ::RecordingStudioApi.register_resource_handler(TYPE, action, api:, handler:)
      end
    end

    def serialize_fields(list, **)
      { name: list.name, description: list.description }
    end
  end
end
