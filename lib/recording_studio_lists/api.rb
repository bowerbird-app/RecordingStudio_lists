# frozen_string_literal: true

require_relative "api/list_resource"
require_relative "api/membership_actions"
require_relative "api/tool_descriptions"

module RecordingStudioLists
  module Api
    TYPE = "RecordingStudio::Lists::List"
    CAPABILITY_ACTIONS = %i[list_add list_remove list_items].freeze
    ADDABLE_ACTION = :list_addable
    OPERATIONS_API = "operations"
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
      type_behavior(api).merge(api:, serializer: method(:serialize_fields), openapi: type_openapi)
    end

    def type_behavior(api)
      {
        operations: %i[index show create update destroy],
        auto_capability_actions: false,
        capability_actions: capability_actions_for(api),
        output_keys: OUTPUT_KEYS,
        writable_attributes: WRITABLE_ATTRIBUTES
      }
    end

    def capability_actions_for(api)
      return CAPABILITY_ACTIONS unless operations_api?(api)

      [*CAPABILITY_ACTIONS, ADDABLE_ACTION]
    end

    def operations_api?(api)
      api.to_s == OPERATIONS_API
    end

    def type_openapi
      ToolDescriptions.type_openapi
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
