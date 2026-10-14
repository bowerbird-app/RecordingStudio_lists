# frozen_string_literal: true

# Backfills Orderable sibling positions from the lists-owned `position` column
# using per-parent ROW_NUMBER (ordered like main's read: position, then id),
# then drops the lists-owned column and check constraint. Requires the
# Orderable migration to have run first.
class MoveListItemPositionsToOrderable < ActiveRecord::Migration[8.1]
  POSITION_CHECK = "recording_studio_list_items_position_check"
  LIST_ITEM_TYPE = "RecordingStudio::Lists::ListItem"
  RENUMBER_POSITIONS_SQL = <<~SQL.squish
    UPDATE recording_studio_list_items AS list_items
    SET position = ordered.position
    FROM (
      SELECT
        recordings.recordable_id AS list_item_id,
        ROW_NUMBER() OVER (
          PARTITION BY recordings.parent_recording_id
          ORDER BY recordings.recording_studio_orderable_position ASC NULLS LAST,
                   recordings.created_at ASC,
                   recordings.id ASC
        ) AS position
      FROM recording_studio_recordings AS recordings
      WHERE recordings.recordable_type = '#{LIST_ITEM_TYPE}'
    ) AS ordered
    WHERE list_items.id = ordered.list_item_id
  SQL
  FILL_NULL_POSITIONS_SQL = <<~SQL.squish
    UPDATE recording_studio_list_items
    SET position = 1
    WHERE position IS NULL
  SQL
  BACKFILL_ORDERABLE_SQL = <<~SQL.squish
    UPDATE recording_studio_recordings AS recordings
    SET recording_studio_orderable_position = ordered.position
    FROM (
      SELECT recordings.id AS recording_id,
             ROW_NUMBER() OVER (
               PARTITION BY recordings.parent_recording_id
               ORDER BY COALESCE(list_items.position, 0) ASC, recordings.id ASC
             ) AS position
      FROM recording_studio_recordings AS recordings
      JOIN recording_studio_list_items AS list_items ON list_items.id = recordings.recordable_id
      WHERE recordings.recordable_type = '#{LIST_ITEM_TYPE}'
    ) AS ordered
    WHERE recordings.id = ordered.recording_id
  SQL

  def up
    ensure_orderable_position_column!

    return unless column_exists?(:recording_studio_list_items, :position)

    backfill_orderable_from_position!
    remove_position_check_constraint!
    remove_column :recording_studio_list_items, :position
  end

  def down
    ensure_orderable_position_column!

    return if column_exists?(:recording_studio_list_items, :position)

    add_column :recording_studio_list_items, :position, :integer
    backfill_position_from_orderable!
    change_column_null :recording_studio_list_items, :position, false
    add_check_constraint :recording_studio_list_items, "position >= 1", name: POSITION_CHECK
  end

  private

  def ensure_orderable_position_column!
    return if column_exists?(:recording_studio_recordings, :recording_studio_orderable_position)

    raise ActiveRecord::MigrationError,
          "recording_studio_orderable_position is missing. " \
          "Run `bin/rails generate recording_studio_orderable:migrations` and " \
          "`bin/rails db:migrate` before this migration."
  end

  def backfill_orderable_from_position!
    execute <<~SQL.squish
      UPDATE recording_studio_recordings AS recordings
      SET recording_studio_orderable_position = ordered.position
      FROM (
        SELECT recordings.id AS recording_id,
               ROW_NUMBER() OVER (
                 PARTITION BY recordings.parent_recording_id
                 ORDER BY COALESCE(list_items.position, 0) ASC, recordings.id ASC
               ) AS position
        FROM recording_studio_recordings AS recordings
        JOIN recording_studio_list_items AS list_items ON list_items.id = recordings.recordable_id
        WHERE recordings.recordable_type = '#{LIST_ITEM_TYPE}'
      ) AS ordered
      WHERE recordings.id = ordered.recording_id
    SQL
  end

  def backfill_position_from_orderable!
    # Orderable may store 0-based indexes after append!/reorder!. Renumber to
    # contiguous 1-based positions per parent so the restored check constraint
    # (`position >= 1`) holds while relative order stays the same.
    execute RENUMBER_POSITIONS_SQL
    execute FILL_NULL_POSITIONS_SQL
  end

  def remove_position_check_constraint!
    return unless check_constraint_exists?(:recording_studio_list_items, name: POSITION_CHECK)

    remove_check_constraint :recording_studio_list_items, name: POSITION_CHECK
  end
end
