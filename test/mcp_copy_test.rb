# frozen_string_literal: true

require "test_helper"

class McpCopyTest < Minitest::Test
  FORBIDDEN = [
    "RecordingStudio::", "Access", "Accessible", ":edit", ":view", "permission", "role",
    "Admin", "staff", "operations"
  ].freeze

  def test_register_is_a_no_op_when_mcp_is_not_loaded
    RecordingStudioLists::McpCopy.stub(:mcp_available?, false) do
      assert_nil RecordingStudioLists::McpCopy.register!
    end
  end

  def test_register_is_a_no_op_when_register_tool_is_missing
    fake = Object.new

    RecordingStudioLists::McpCopy.stub(:mcp, fake) do
      RecordingStudioLists::McpCopy.stub(:mcp_available?, false) do
        refute_respond_to fake, :register_tool
        assert_nil RecordingStudioLists::McpCopy.register!
      end
    end
  end

  def test_register_declares_list_type_and_named_tools
    fake = RecordingMcp.new

    RecordingStudioLists::McpCopy.stub(:mcp_available?, true) do
      RecordingStudioLists::McpCopy.stub(:mcp, fake) do
        RecordingStudioLists::McpCopy.register!
        RecordingStudioLists::McpCopy.register!
      end
    end

    assert_equal 2, fake.types.size
    registration = fake.types.first
    assert_equal "RecordingStudio::Lists::List", registration[:type]
    assert_equal RecordingStudioLists::McpCopy::Copy::TYPE, registration[:description]
    assert_includes registration[:description], "workspace"
    assert_includes registration[:description], "create_list"
    refute_includes registration[:description], "list_items"
    refute_includes registration[:description], "ListSection"
    FORBIDDEN.each { |phrase| refute_includes registration[:description], phrase }

    expected = RecordingStudioLists::McpCopy.tool_names.fetch(:public)
    assert_equal expected, fake.tools.keys
    expected.each do |name|
      tool = fake.tools.fetch(name)
      assert_equal "RecordingStudio::Lists::List", tool[:type]
      assert_equal RecordingStudioLists::McpCopy::Copy::TITLES.fetch(name), tool[:title]
      assert_equal RecordingStudioLists::McpCopy::Copy::DESCRIPTIONS.fetch(name), tool[:description]
      assert_equal RecordingStudioLists::McpCopy::Copy::INPUTS.fetch(name), tool[:input]
      assert_equal RecordingStudioLists::McpCopy::Copy::OUTPUTS.fetch(name), tool[:output]
      assert_includes tool[:description], "named collection"
      refute_includes tool[:description], "list_items"
      FORBIDDEN.each { |phrase| refute_includes tool[:description], phrase }
    end

    list = fake.tools.fetch("list_lists")
    assert_equal :index, list[:operation]
    refute list.key?(:action)
    create = fake.tools.fetch("create_list")
    assert_equal :create, create[:operation]
    assert create[:input].key?("name")
    add = fake.tools.fetch("add_to_list")
    assert_equal :list_add, add[:action]
    refute add.key?(:operation)
    members = fake.tools.fetch("list_list_members")
    assert_equal :list_items, members[:action]
    refute fake.tools.key?("list_addable")
    refute fake.tools.key?("list_items")
    refute fake.tools.key?("add_list_item")
  end

  def test_writable_inputs_use_api_tool_copy
    inputs = RecordingStudioLists::McpCopy::Copy::INPUTS
    copy = RecordingStudioLists::Api::ToolCopy

    assert_equal copy::NAME, inputs.fetch("create_list").fetch("name").fetch(:description)
    assert_equal copy::DESCRIPTION, inputs.fetch("update_list").fetch("description").fetch(:description)
    assert_equal copy::ADD_RECORDING_ID, inputs.fetch("add_to_list").fetch("recording_id").fetch(:description)
  end

  def test_tool_names_split_public_and_operations
    names = RecordingStudioLists::McpCopy.tool_names

    assert_equal %w[
      list_lists show_list create_list update_list delete_list
      add_to_list remove_from_list list_list_members
    ], names.fetch(:public)
    assert_equal [], names.fetch(:operations)
    refute_includes names.fetch(:public), "list_addable"
    refute_includes names.fetch(:public), "list_items"
  end

  def test_gemspec_does_not_depend_on_recording_studio_mcp
    gemspec = File.read(File.expand_path("../recording_studio_lists.gemspec", __dir__))
    entry = File.read(File.expand_path("../lib/recording_studio_lists.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_lists/engine.rb", __dir__))

    refute_includes gemspec, "recording_studio_mcp"
    refute_includes gemspec, "recording_studio_metrics"
    refute_includes entry, 'require "recording_studio_mcp"'
    refute_includes entry, 'require "recording_studio_metrics"'
    assert_includes engine, 'require_relative "mcp_copy"'
    assert_includes engine, 'require_relative "metrics"'
    assert_includes engine, 'initializer "recording_studio_lists.mcp", after: "recording_studio_lists.api"'
    assert_includes engine, "McpCopy.register!"
    assert_includes engine, 'initializer "recording_studio_lists.metrics", after: "recording_studio_lists.mcp"'
    assert_includes engine, "Metrics.register! if defined?(::RecordingStudioMetrics)"
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

  class RecordingMcp
    attr_reader :types, :tools

    def initialize
      @types = []
      @tools = {}
    end

    def register_type(**registration)
      types << registration
    end

    def register_tool(**registration)
      tools[registration.fetch(:name)] = registration
    end
  end
end
