# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "test_helper"
require_relative "dummy/config/environment"

require "rails/test_help"

class ListsBehaviorTest < ActiveSupport::TestCase
  test "list and list item declarations validate" do
    assert RecordingStudio.validate_recordable_declarations!

    list_declaration = RecordingStudio.recordable_declaration_for("RecordingStudio::Lists::List")
    item_declaration = RecordingStudio.recordable_declaration_for("RecordingStudio::Lists::ListItem")

    refute list_declaration.root?
    assert_empty RecordingStudio.declared_allowed_parent_types_for("RecordingStudio::Lists::List")
    assert_equal ["Workspace"], RecordingStudio.allowed_parent_types_for("RecordingStudio::Lists::List")
    refute item_declaration.root?
    assert_equal ["RecordingStudio::Lists::List"], item_declaration.allowed_parent_types
    assert RecordingStudio.capability_enabled?(:lists, for: Workspace)
  end

  test "list is not a root and a list item cannot sit under a workspace" do
    list = RecordingStudio::Lists::List.create!(name: unique_name("Loose List"))
    assert_raises(RecordingStudio::RootNotAllowed) do
      RecordingStudio.root_recording_for(list)
    end

    root = workspace_root
    error = assert_raises(RecordingStudio::InvalidParent) do
      root.record(RecordingStudio::Lists::ListItem, parent_recording: root) do |item|
        item.item_recording = root
        item.position = 1
      end
    end
    assert_match(/cannot be recorded under/, error.message)
  end

  test "list creation waits for the lists capability and then hangs under the parent" do
    root = workspace_root

    without_lists_capability do
      refute RecordingStudio.parent_allowed?(child_type: "RecordingStudio::Lists::List", parent_recording: root)
      assert_raises(RecordingStudio::InvalidParent) do
        RecordingStudio.record!(
          action: "created",
          recordable: RecordingStudio::Lists::List.new(name: "Blocked"),
          root_recording: root,
          parent_recording: root
        )
      end
      assert_no_difference -> { RecordingStudio::Recording.where(recordable_type: "RecordingStudio::Lists::List").count } do
        assert_raises(RecordingStudio::Lists::ParentNotAllowed) do
          RecordingStudio::Lists.create(parent: root, name: "Blocked")
        end
      end
    end

    list = RecordingStudio::Lists.create(parent: root, name: "Shelf", description: "Notes")

    assert_equal root, list.parent_recording
    assert_equal root.id, list.root_recording_id
    assert_instance_of RecordingStudio::Lists::List, list.recordable
    assert_equal "Shelf", list.recordable.name
    assert_equal "Notes", list.recordable.description
    refute RecordingStudio.root_recording?(list)
    assert_equal list, RecordingStudio::Lists.find(list.id)
  end

  test "blank name is rejected before a list is written" do
    root = workspace_root

    assert_no_difference -> { RecordingStudio::Lists::List.count } do
      assert_raises(RecordingStudio::Lists::BlankName) do
        RecordingStudio::Lists.create(parent: root, name: "  ")
      end
    end
  end

  test "add appends list item children in position order and keeps a repeated add still" do
    root = workspace_root
    first = page_under(root, "First")
    second = page_under(root, "Second")
    list = RecordingStudio::Lists.create(parent: root, name: "Order")
    other = RecordingStudio::Lists.create(parent: root, name: "Also")

    assert_equal first, RecordingStudio::Lists.add(list, first.id)
    child = list_item_for(list, first)
    assert_equal "RecordingStudio::Lists::ListItem", child.recordable_type
    assert_equal first.id, child.recordable.item_recording_id
    assert_equal list.id, child.parent_recording_id
    assert_equal 1, child.recordable.position

    assert_no_difference -> { RecordingStudio::Recording.where(parent_recording_id: list.id).count } do
      assert_equal first, RecordingStudio::Lists.add(list, first)
    end
    assert_equal 1, list_item_for(list, first).recordable.position

    RecordingStudio::Lists.add(list, second)
    assert_equal [first, second], RecordingStudio::Lists.items(list)
    assert_equal [1, 2], item_positions(list)

    RecordingStudio::Lists.add(other, first)
    assert_equal [first], RecordingStudio::Lists.items(other)
    assert_equal [first, second], RecordingStudio::Lists.items(list)
    assert_equal 3, RecordingStudio::Recording.where(recordable_type: "RecordingStudio::Lists::ListItem").count
  end

  test "remove and delete drop list recordings and leave the target" do
    root = workspace_root
    target = page_under(root, "Kept")
    list = RecordingStudio::Lists.create(parent: root, name: "Temporary")
    RecordingStudio::Lists.add(list, target)
    child = list_item_for(list, target)
    snapshot_id = child.recordable_id

    assert_equal target, RecordingStudio::Lists.remove(list, target.id)
    refute RecordingStudio::Recording.exists?(child.id)
    assert RecordingStudio::Lists::ListItem.exists?(snapshot_id)
    assert RecordingStudio::Recording.exists?(target.id)

    RecordingStudio::Lists.add(list, target)
    child = list_item_for(list, target)
    list_id = list.id
    child_id = child.id
    snapshot_id = child.recordable_id

    assert_equal list, RecordingStudio::Lists.delete(list.id)
    refute RecordingStudio::Recording.exists?(list_id)
    refute RecordingStudio::Recording.exists?(child_id)
    assert RecordingStudio::Lists::ListItem.exists?(snapshot_id)
    assert RecordingStudio::Recording.exists?(target.id)
    assert_nil RecordingStudio::Lists.delete(SecureRandom.uuid)
    assert_raises(RecordingStudio::Lists::InvalidList) { RecordingStudio::Lists.delete(target) }
    assert_raises(RecordingStudio::Lists::InvalidList) { RecordingStudio::Lists.find(target.id) }
  end

  test "keyed create returns the same list recording" do
    root = workspace_root
    key = "list-#{SecureRandom.hex(8)}"

    created = RecordingStudio::Lists.create(parent: root, name: "Once", idempotency_key: key)
    again = RecordingStudio::Lists.create(parent: root, name: "Twice", idempotency_key: key)

    assert_equal created.id, again.id
    assert_equal "Once", created.reload.name
    assert_equal 1, RecordingStudio::Recording.where(parent_recording_id: root.id, recordable_type: "RecordingStudio::Lists::List").count
  end

  test "add rejects the list itself, a list item, a missing target, and another tree" do
    root = workspace_root
    elsewhere = workspace_root("Elsewhere")
    page = page_under(root, "Local")
    foreign = page_under(elsewhere, "Foreign")
    list = RecordingStudio::Lists.create(parent: root, name: "Picky")

    assert_raises(RecordingStudio::Lists::SelfTarget) { RecordingStudio::Lists.add(list, list) }
    assert_raises(RecordingStudio::Lists::MissingTarget) { RecordingStudio::Lists.add(list, SecureRandom.uuid) }
    assert_raises(RecordingStudio::Lists::DifferentRoot) { RecordingStudio::Lists.add(list, foreign) }

    RecordingStudio::Lists.add(list, page)
    item = list_item_for(list, page)
    assert_raises(RecordingStudio::Lists::ListItemTarget) { RecordingStudio::Lists.add(list, item) }
    assert_equal [page], RecordingStudio::Lists.items(list)
  end

  test "lists are ordered by name and addable skips members and list records" do
    root = workspace_root
    kept = page_under(root, "Kept Page")
    open_page = page_under(root, "Open Page")
    RecordingStudio::Lists.create(parent: root, name: "Zed")
    RecordingStudio::Lists.create(parent: root, name: "Amy")
    list = RecordingStudio::Lists.lists(root).find { |candidate| candidate.name == "Amy" }

    assert_equal %w[Amy Zed], RecordingStudio::Lists.lists(root).map(&:name)

    RecordingStudio::Lists.add(list, kept)
    candidates = RecordingStudio::Lists.addable(list)

    assert_includes candidates, open_page
    assert_includes candidates, root
    refute_includes candidates, kept
    refute_includes candidates, list
    refute_includes candidates.map(&:recordable_type), "RecordingStudio::Lists::List"
    refute_includes candidates.map(&:recordable_type), "RecordingStudio::Lists::ListItem"
    expected_ids = RecordingStudio::Recording.where(id: candidates.map(&:id)).order(:created_at, :id).map(&:id)
    assert_equal expected_ids, candidates.map(&:id)
  end

  private

  def without_lists_capability
    RecordingStudio.configuration.instance_variable_get(:@capabilities)["Workspace"].delete(:lists)
    yield
  ensure
    RecordingStudio.enable_capability(:lists, on: Workspace)
  end

  def workspace_root(prefix = "Lists Workspace")
    RecordingStudio.root_recording_for(Workspace.create!(name: unique_name(prefix)))
  end

  def page_under(root, title)
    RecordingStudio.record!(
      action: "created",
      recordable: Page.new(title: unique_name(title)),
      root_recording: root,
      parent_recording: root
    ).recording
  end

  def list_item_for(list, target)
    list.child_recordings.reload.find { |child| child.recordable.item_recording_id == target.id }
  end

  def item_positions(list)
    list.child_recordings.reload.map { |child| child.recordable.position }.sort
  end

  def unique_name(prefix)
    "#{prefix} #{SecureRandom.hex(4)}"
  end
end
