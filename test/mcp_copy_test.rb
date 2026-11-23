# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
  FORBIDDEN = [
    "RecordingStudio::", "Access", "Accessible", ":edit", ":view", "permission", "role",
    "Admin", "staff", "operations"
  ].freeze

  def test_register_is_a_no_op_when_mcp_is_not_loaded
    hide_mcp_constant

    refute defined?(::RecordingStudioMcp)
    assert_nil RecordingStudioLists::McpCopy.register!
  ensure
    restore_mcp_constant
  end

  def test_register_is_a_no_op_when_register_tool_is_missing
    hide_mcp_constant
    Object.const_set(:RecordingStudioMcp, Module.new)

    refute_respond_to RecordingStudioMcp, :register_tool
    assert_nil RecordingStudioLists::McpCopy.register!
  ensure
    restore_mcp_constant
  end

  def test_register_declares_list_type_and_named_tools
    hide_mcp_constant
    types = []
    tools = {}
    stub_mcp(types: types, tools: tools)

    RecordingStudioLists::McpCopy.register!
    RecordingStudioLists::McpCopy.register!

    assert_equal 2, types.size
    registration = types.first
    assert_equal "RecordingStudio::Lists::List", registration[:type]
    assert_equal RecordingStudioLists::McpCopy::Copy::TYPE, registration[:description]
    assert_equal "List", RecordingStudioLists::McpCopy::PUBLIC_TYPE_NAME
    assert_includes registration[:description], "workspace"
    assert_includes registration[:description], "create_list"
    refute_includes registration[:description], "list_items"
    refute_includes registration[:description], "ListSection"
    FORBIDDEN.each { |phrase| refute_includes registration[:description], phrase }

    expected = RecordingStudioLists::McpCopy.tool_names.fetch(:operations)
    assert_equal expected, tools.keys
    expected.each do |name|
      tool = tools.fetch(name)
      assert_equal "RecordingStudio::Lists::List", tool[:type]
      assert_equal RecordingStudioLists::McpCopy::Copy::TITLES.fetch(name), tool[:title]
      assert_equal RecordingStudioLists::McpCopy::Copy::DESCRIPTIONS.fetch(name), tool[:description]
      assert_equal RecordingStudioLists::McpCopy::Copy::INPUTS.fetch(name), tool[:input]
      assert_equal RecordingStudioLists::McpCopy::Copy::OUTPUTS.fetch(name), tool[:output]
      assert_includes tool[:description], "named collection"
      refute_includes tool[:description], "list_items"
      FORBIDDEN.each { |phrase| refute_includes tool[:description], phrase }
    end

    list = tools.fetch("list_lists")
    assert_equal :index, list[:operation]
    refute list.key?(:action)
    create = tools.fetch("create_list")
    assert_equal :create, create[:operation]
    assert create[:input].key?("name")
    add = tools.fetch("add_to_list")
    assert_equal :list_add, add[:action]
    refute add.key?(:operation)
    members = tools.fetch("list_list_members")
    assert_equal :list_items, members[:action]
    addable = tools.fetch("list_addable")
    assert_equal :list_addable, addable[:action]
    refute tools.key?("list_items")
    refute tools.key?("add_list_item")
  ensure
    restore_mcp_constant
  end

  def test_tool_names_split_public_and_operations
    names = RecordingStudioLists::McpCopy.tool_names

    assert_equal %w[
      list_lists show_list create_list update_list delete_list
      add_to_list remove_from_list list_list_members
    ], names.fetch(:public)
    assert_equal names.fetch(:public) + %w[list_addable], names.fetch(:operations)
    refute_includes names.fetch(:public), "list_addable"
    refute_includes names.fetch(:public), "list_items"
    names.fetch(:operations).each { |name| assert_match(/\A[A-Za-z][A-Za-z0-9_.-]*\z/, name) }
  end

  def test_gemspec_does_not_depend_on_recording_studio_mcp
    gemspec = File.read(File.expand_path("../recording_studio_lists.gemspec", __dir__))
    entry = File.read(File.expand_path("../lib/recording_studio_lists.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_lists/engine.rb", __dir__))

    refute_includes gemspec, "recording_studio_mcp"
    refute_includes entry, 'require "recording_studio_mcp"'
    assert_includes engine, 'require_relative "mcp_copy"'
    assert_includes engine, 'initializer "recording_studio_lists.mcp", after: "recording_studio_lists.api"'
    assert_includes engine, "McpCopy.register!"
  end

  def test_writes_state_prerequisites_and_every_tool_has_output
    copy = RecordingStudioLists::McpCopy::Copy

    assert_includes copy::CREATE, "Do this before add_to_list"
    assert_includes copy::ADD, "Create the list with create_list first"
    assert_includes copy::UPDATE, "The list must already exist"
    assert_includes copy::DELETE, "cannot be undone"
    assert_includes copy::REMOVE, "list_list_members"
    copy::TITLES.each_key do |name|
      phrase = copy::OUTPUTS.fetch(name)
      assert_kind_of String, phrase
      refute_empty phrase, name
    end
  end

  private

  def stub_mcp(types:, tools:)
    mcp = Module.new
    mcp.define_singleton_method(:register_type) { |**registration| types << registration }
    mcp.define_singleton_method(:register_tool) do |**registration|
      tools[registration.fetch(:name)] = registration
    end
    Object.const_set(:RecordingStudioMcp, mcp)
    mcp
  end

  def hide_mcp_constant
    @saved_mcp = defined?(::RecordingStudioMcp) ? ::RecordingStudioMcp : :absent
    Object.send(:remove_const, :RecordingStudioMcp) if defined?(::RecordingStudioMcp)
  end

  def restore_mcp_constant
    Object.send(:remove_const, :RecordingStudioMcp) if defined?(::RecordingStudioMcp)
    return if @saved_mcp == :absent || @saved_mcp.nil?

    Object.const_set(:RecordingStudioMcp, @saved_mcp)
  end
end
