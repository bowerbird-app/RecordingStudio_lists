# frozen_string_literal: true

require_relative "mcp_copy/copy"

module RecordingStudioLists
  # Registers List named MCP tools when Recording Studio MCP is loaded.
  # This gem does not depend on it. Hosts that skip MCP keep the UI and API only.
  module McpCopy
    RECORDABLE_TYPE = Api::TYPE
    PUBLIC_TYPE_NAME = "List"
    PUBLIC_TOOL_NAMES = %w[
      list_lists show_list create_list update_list delete_list
      add_to_list remove_from_list list_list_members
    ].freeze
    OPERATIONS_ONLY_TOOL_NAMES = %w[list_addable].freeze
    OPERATIONS_TOOL_NAMES = (PUBLIC_TOOL_NAMES + OPERATIONS_ONLY_TOOL_NAMES).freeze
    OPERATIONS = {
      "list_lists" => :index,
      "show_list" => :show,
      "create_list" => :create,
      "update_list" => :update,
      "delete_list" => :destroy
    }.freeze
    ACTIONS = {
      "add_to_list" => :list_add,
      "remove_from_list" => :list_remove,
      "list_list_members" => :list_items,
      "list_addable" => :list_addable
    }.freeze

    module_function

    def register!
      # Isolated gem tests load this file without RecordingStudioMcp.
      # Dummy and hosts already have the gem. The engine calls this on
      # to_prepare; hosts do not. MCP 0.40.0 lets the same type and target
      # re-register copy, so a second call does not duplicate or raise.
      return unless defined?(::RecordingStudioMcp)
      return unless ::RecordingStudioMcp.respond_to?(:register_tool)

      register_types
      register_tools(OPERATIONS_TOOL_NAMES)
    end

    def tool_names
      { public: PUBLIC_TOOL_NAMES, operations: OPERATIONS_TOOL_NAMES }
    end

    def register_types
      return unless ::RecordingStudioMcp.respond_to?(:register_type)

      ::RecordingStudioMcp.register_type(type: RECORDABLE_TYPE, description: Copy::TYPE)
    end

    def register_tools(names)
      names.each { |name| register_named_tool(name) }
    end

    def register_named_tool(name)
      ::RecordingStudioMcp.register_tool(**tool_registration(name))
    end

    def tool_registration(name)
      {
        name: name,
        type: RECORDABLE_TYPE,
        title: Copy::TITLES.fetch(name),
        description: Copy::DESCRIPTIONS.fetch(name),
        input: Copy::INPUTS.fetch(name),
        output: Copy::OUTPUTS.fetch(name)
      }.merge(tool_target(name))
    end

    def tool_target(name)
      return { operation: OPERATIONS.fetch(name) } if OPERATIONS.key?(name)

      { action: ACTIONS.fetch(name) }
    end
  end
end
