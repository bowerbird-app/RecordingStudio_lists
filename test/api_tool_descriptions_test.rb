# frozen_string_literal: true

require "test_helper"

class ApiToolDescriptionsTest < Minitest::Test
  OPERATIONS = %i[index show create update destroy].freeze
  ACTIONS = %i[add remove items addable].freeze
  FORBIDDEN = ["RecordingStudio::", "Path parameter"].freeze

  def test_every_tool_and_input_has_a_plain_description
    texts = description_texts

    assert_operator texts.size, :>, 10
    texts.each do |text|
      assert_kind_of String, text
      refute_empty text.strip, "blank description"
      FORBIDDEN.each { |phrase| refute_includes text, phrase }
    end
  end

  def test_section_intro_is_not_copied_onto_each_tool
    openapi = RecordingStudioLists::Api.type_openapi
    intro = openapi.dig(:tag, :description)

    assert_equal intro, openapi.fetch(:description)
    assert_includes intro, "Q3 launch coverage"
    refute_includes intro, "Named lists of recordings"
    OPERATIONS.each { |name| refute_includes openapi.dig(name, :description), "Q3 launch coverage" }
    ACTIONS.each do |name|
      docs = membership.public_send("#{name}_docs")
      refute_includes docs.fetch(:description), "Q3 launch coverage"
    end
  end

  def test_required_inputs_say_where_the_value_comes_from
    openapi = RecordingStudioLists::Api.type_openapi

    assert_includes openapi.dig(:details_schema, :properties, :name, :description), "name"
    assert_includes openapi.dig(:details_schema, :properties, :description, :description), "update"
    assert_includes parent_description(openapi), "parent"
    index_parameters = openapi.dig(:index, :parameters)
    assert_includes index_parameters.map { |parameter| parameter.fetch(:name) }, "parent_id"
    query = index_parameters.find { |parameter| parameter.fetch(:name) == "q" }
    assert_includes query.fetch(:description), "ignored"
    assert_includes index_parameters.first.fetch(:description), "holds the lists"
    %i[show update destroy].each do |name|
      assert_includes openapi.dig(name, :parameters, 0, :description), "index"
    end
    assert_includes membership.add_contract.dig(:fields, :recording_id, :description), "List - Addable"
    assert_includes membership.remove_contract.dig(:fields, :recording_id, :description), "List - Items"
    ACTIONS.each do |name|
      assert_includes membership.public_send("#{name}_docs").dig(:parameters, 0, :description), "index"
    end
  end

  private

  def membership
    RecordingStudioLists::Api::MembershipActions
  end

  def parent_description(openapi)
    openapi.dig(:create, :request_body, :content, "application/json", :schema, :properties, :parent_id, :description)
  end

  def description_texts
    texts = []
    collect(RecordingStudioLists::Api.type_openapi, texts)
    ACTIONS.each do |name|
      collect(membership.public_send("#{name}_docs"), texts)
      collect(membership.public_send("#{name}_contract"), texts) if %i[add remove].include?(name)
    end
    texts
  end

  def collect(value, texts)
    case value
    when Hash
      value.each do |key, child|
        texts << child if key.to_s == "description" && child.is_a?(String)
        collect(child, texts)
      end
    when Array
      value.each { |child| collect(child, texts) }
    end
  end
end
