# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "test_helper"
require_relative "dummy/config/environment"

require "rails/test_help"

class MoveListItemPositionsToOrderableMigrationTest < ActiveSupport::TestCase
  MIGRATION_PATH = File.expand_path(
    "dummy/db/migrate/20261014050001_move_list_item_positions_to_orderable.rb",
    __dir__
  )

  setup do
    load MIGRATION_PATH unless defined?(MoveListItemPositionsToOrderable)
    @migration = MoveListItemPositionsToOrderable.new
    @connection = ActiveRecord::Base.connection
  end

  test "up copies position values onto orderable storage and preserves item order" do
    root = workspace_root
    first = page_under(root, "First")
    second = page_under(root, "Second")
    third = page_under(root, "Third")
    list = RecordingStudio::Lists.create(parent: root, name: unique_name("Migrate Order"))

    RecordingStudio::Lists.add(list, first)
    RecordingStudio::Lists.add(list, second)
    RecordingStudio::Lists.add(list, third)

    children_before = list.recording_studio_orderable_children.to_a
    assert_equal [first, second, third], RecordingStudio::Lists.items(list)

    # Put the schema back to the lists-owned position column and seed non-sequential
    # values so the backfill cannot accidentally rely on creation order alone.
    @migration.down
    assert @connection.column_exists?(:recording_studio_list_items, :position)

    seed_owned_positions!(
      children_before[0] => 10,
      children_before[1] => 20,
      children_before[2] => 30
    )
    clear_orderable_positions!(children_before)

    @migration.up

    refute @connection.column_exists?(:recording_studio_list_items, :position)
    assert @connection.column_exists?(:recording_studio_recordings, :recording_studio_orderable_position)

    list.reload
    children_after = list.recording_studio_orderable_children.reload.to_a
    assert_equal children_before.map(&:id), children_after.map(&:id)
    assert_equal [10, 20, 30], children_after.map(&:recording_studio_orderable_position)
    assert_equal [first, second, third], RecordingStudio::Lists.items(list)

    # Existing call sites still append and read in order after the migration.
    fourth = page_under(root, "Fourth")
    RecordingStudio::Lists.add(list, fourth)
    assert_equal [first, second, third, fourth], RecordingStudio::Lists.items(list)
  end

  test "down restores the position column from orderable values" do
    root = workspace_root
    first = page_under(root, "Down First")
    second = page_under(root, "Down Second")
    list = RecordingStudio::Lists.create(parent: root, name: unique_name("Migrate Down"))
    RecordingStudio::Lists.add(list, first)
    RecordingStudio::Lists.add(list, second)

    children = list.recording_studio_orderable_children.to_a
    # 0-based Orderable values must become valid 1-based positions on rollback.
    children[0].update!(recording_studio_orderable_position: 0)
    children[1].update!(recording_studio_orderable_position: 5)

    @migration.down

    assert @connection.column_exists?(:recording_studio_list_items, :position)
    assert_equal 1, position_for(children[0])
    assert_equal 2, position_for(children[1])
    assert check_constraint_present?
    assert_equal [first.id, second.id], item_recording_ids_by_position(list)

    @migration.up
  end

  private

  def seed_owned_positions!(mapping)
    mapping.each do |recording, position|
      @connection.execute(<<~SQL.squish)
        UPDATE recording_studio_list_items
        SET position = #{position.to_i}
        WHERE id = '#{recording.recordable_id}'
      SQL
    end
  end

  def clear_orderable_positions!(recordings)
    ids = recordings.map { |recording| "'#{recording.id}'" }.join(", ")
    @connection.execute(<<~SQL.squish)
      UPDATE recording_studio_recordings
      SET recording_studio_orderable_position = NULL
      WHERE id IN (#{ids})
    SQL
  end

  def position_for(recording)
    @connection.select_value(<<~SQL.squish).to_i
      SELECT position
      FROM recording_studio_list_items
      WHERE id = '#{recording.recordable_id}'
    SQL
  end

  def item_recording_ids_by_position(list)
    @connection.select_values(<<~SQL.squish)
      SELECT list_items.item_recording_id
      FROM recording_studio_list_items AS list_items
      INNER JOIN recording_studio_recordings AS recordings
        ON recordings.recordable_id = list_items.id
       AND recordings.recordable_type = 'RecordingStudio::Lists::ListItem'
      WHERE recordings.parent_recording_id = '#{list.id}'
      ORDER BY list_items.position ASC, recordings.id ASC
    SQL
  end

  def check_constraint_present?
    @connection.check_constraints(:recording_studio_list_items).any? do |constraint|
      constraint.name == "recording_studio_list_items_position_check"
    end
  end

  def workspace_root(prefix = "Migration Workspace")
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

  def unique_name(prefix)
    "#{prefix} #{SecureRandom.hex(4)}"
  end
end
