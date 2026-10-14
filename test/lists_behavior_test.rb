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
    assert RecordingStudio.capability_enabled?(:orderable, for: "RecordingStudio::Lists::List")
    assert_equal(
      { allows: ["RecordingStudio::Lists::ListItem"] },
      RecordingStudio.capability_options(:orderable, for: "RecordingStudio::Lists::List")
    )
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
      scope = RecordingStudio::Recording.where(recordable_type: "RecordingStudio::Lists::List")
      assert_no_difference -> { scope.count } do
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
    assert_equal 1, child.recording_studio_orderable_position

    assert_no_difference -> { RecordingStudio::Recording.where(parent_recording_id: list.id).count } do
      assert_equal first, RecordingStudio::Lists.add(list, first)
    end
    assert_equal 1, list_item_for(list, first).recording_studio_orderable_position

    RecordingStudio::Lists.add(list, second)
    assert_equal [first, second], RecordingStudio::Lists.items(list)
    assert_equal [1, 2], item_positions(list)
    ordered_item_ids = list.recording_studio_orderable_children.map { |child| child.recordable.item_recording_id }
    assert_equal [first.id, second.id], ordered_item_ids

    RecordingStudio::Lists.add(other, first)
    assert_equal [first], RecordingStudio::Lists.items(other)
    assert_equal [first, second], RecordingStudio::Lists.items(list)
    assert_equal 3, RecordingStudio::Recording.where(recordable_type: "RecordingStudio::Lists::ListItem").count
  end

  test "add writes max+1 without renumbering siblings or logging reordered" do
    root = workspace_root
    first = page_under(root, "Keep")
    second = page_under(root, "Next")
    list = RecordingStudio::Lists.create(parent: root, name: "No Reorder Event")

    RecordingStudio::Lists.add(list, first)
    existing = list_item_for(list, first)
    existing.update!(recording_studio_orderable_position: 7)
    sibling_updated_at = existing.reload.updated_at

    assert_no_difference -> { reorder_event_count(list) } do
      RecordingStudio::Lists.add(list, second)
    end

    existing.reload
    assert_equal 7, existing.recording_studio_orderable_position
    assert_equal sibling_updated_at.to_i, existing.updated_at.to_i
    assert_equal 8, list_item_for(list, second).recording_studio_orderable_position
    assert_equal [first, second], RecordingStudio::Lists.items(list)
  end

  test "reorder through orderable keeps Lists.items in the new order" do
    root = workspace_root
    first = page_under(root, "Alpha")
    second = page_under(root, "Beta")
    third = page_under(root, "Gamma")
    list = RecordingStudio::Lists.create(parent: root, name: "Reorder")

    RecordingStudio::Lists.add(list, first)
    RecordingStudio::Lists.add(list, second)
    RecordingStudio::Lists.add(list, third)
    assert_equal [first, second, third], RecordingStudio::Lists.items(list)

    children = list.recording_studio_orderable_children.to_a
    list.recording_studio_orderable_reorder!(
      ordered_recording_ids: [children[2].id, children[0].id, children[1].id]
    )

    assert_equal [third, first, second], RecordingStudio::Lists.items(list)
    assert_equal [0, 1, 2], item_positions(list)
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

  test "return paths stay on this site" do
    assert_equal "/lists", RecordingStudio::Lists::InternalPath.sanitize("/lists")
    assert_equal "/lists?x=1", RecordingStudio::Lists::InternalPath.sanitize("  /lists?x=1  ")
    assert_nil RecordingStudio::Lists::InternalPath.sanitize(nil)
    assert_nil RecordingStudio::Lists::InternalPath.sanitize("lists")
    assert_nil RecordingStudio::Lists::InternalPath.sanitize("https://evil.test/phish")
    assert_nil RecordingStudio::Lists::InternalPath.sanitize("//evil.test")
    assert_nil RecordingStudio::Lists::InternalPath.sanitize("/\\evil.test")
    assert_nil RecordingStudio::Lists::InternalPath.sanitize("/%2f/evil")
    assert_nil RecordingStudio::Lists::InternalPath.sanitize("/%2F/evil")
    assert_nil RecordingStudio::Lists::InternalPath.sanitize("/lists\nSet-Cookie: x")
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
    list.recording_studio_orderable_children.reload.map(&:recording_studio_orderable_position)
  end

  def reorder_event_count(list)
    RecordingStudio::Event.where(recording_id: list.id, action: "reordered").count
  end

  def unique_name(prefix)
    "#{prefix} #{SecureRandom.hex(4)}"
  end
end
