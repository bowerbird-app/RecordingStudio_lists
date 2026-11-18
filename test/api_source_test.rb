# frozen_string_literal: true

require "test_helper"

class ApiSourceTest < Minitest::Test
  def test_register_has_one_api_availability_check
    source = File.read(File.expand_path("../lib/recording_studio_lists/api.rb", __dir__))

    assert_equal 1, source.scan("defined?(::RecordingStudioApi)").size
    refute_includes source, "const_set"
    refute_includes source, "remove_const"
    assert_includes source, "configuration.each_api"
    assert_includes source, "ToolDescriptions.type_openapi"
    refute_includes source, "Named lists of recordings"
    assert_includes source, "auto_capability_actions: false"
    assert_includes source, "capability_actions: capability_actions_for(api)"
    assert_includes source, "%i[list_add list_remove list_items].freeze"
    assert_includes source, "ADDABLE_ACTION = :list_addable"
    assert_includes source, "def operations_api?"
  end

  def test_handlers_wrap_existing_list_methods
    resource = File.read(File.expand_path("../lib/recording_studio_lists/api/list_resource.rb", __dir__))
    membership = File.read(File.expand_path("../lib/recording_studio_lists/api/membership_actions.rb", __dir__))

    assert_includes resource, "AccessibleLists.for(actor: @context.actor, parent:, minimum_role: :view)"
    assert_includes resource, "RecordingStudio::Lists.find"
    assert_includes resource, "RecordingStudio::Lists.create"
    assert_includes resource, "RecordingStudio::Lists.update"
    assert_includes resource, "RecordingStudio::Lists.delete"
    assert_includes membership, "RecordingStudio::Lists.add"
    assert_includes membership, "RecordingStudio::Lists.remove"
    assert_includes membership, "RecordingStudio::Lists.items"
    assert_includes membership, "RecordingStudio::Lists.addable"
    assert_includes membership, "capability_action(name, api:"
    assert_includes membership, "reject_unknown: false"
    assert_includes membership, "name: :list_add"
    assert_includes membership, "name: :list_remove"
    assert_includes membership, "name: :list_items"
    assert_includes membership, "register_addable(api) if RecordingStudioLists::Api.operations_api?(api)"
    assert_includes membership, "name: :list_addable"
    assert_includes membership, "capability: :list_membership"
    refute_includes membership, "capability: :orderable"
    refute_includes membership, "capability: :lists"
    refute_includes membership, "name: :add,"
    assert_includes membership, "ToolDescriptions.add"
    assert_includes membership, "ToolDescriptions.remove"
    copy = File.read(File.expand_path("../lib/recording_studio_lists/api/tool_descriptions.rb", __dir__))
    assert_includes copy, "Add to list"
    assert_includes copy, "Remove from list"
    refute_includes copy, "List - "
    refute_includes resource, "ListItem.create"
    refute_includes membership, "ListItem.create"
    refute_includes resource, "deep_symbolize_keys"
    refute_includes resource, "transform_keys"
    assert_includes resource, "RequestPayload.call(context)"
  end

  def test_list_addable_is_listed_only_for_the_operations_api
    public_actions = RecordingStudioLists::Api.capability_actions_for(:public)
    operations_actions = RecordingStudioLists::Api.capability_actions_for("operations")
    other_actions = RecordingStudioLists::Api.capability_actions_for(:workspace)

    assert_equal %i[list_add list_remove list_items], public_actions
    assert_equal %i[list_add list_remove list_items list_addable], operations_actions
    assert_equal public_actions, other_actions
    refute RecordingStudioLists::Api.operations_api?(:public)
    assert RecordingStudioLists::Api.operations_api?(:operations)
  end

  def test_engine_registers_the_api_after_reload
    names = RecordingStudioLists::Engine.initializers.map(&:name)

    assert_includes names, "recording_studio_lists.api"
  end

  def test_does_not_fake_recording_studio_api
    Dir[File.expand_path("../lib/**/*.rb", __dir__)].each do |path|
      source = File.read(path)
      refute_includes source, "const_set", "#{path} must not fake constants"
      refute_includes source, "remove_const", "#{path} must not fake constants"
    end
  end
end
