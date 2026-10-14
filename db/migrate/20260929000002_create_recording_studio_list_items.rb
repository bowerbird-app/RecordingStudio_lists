# frozen_string_literal: true

class CreateRecordingStudioListItems < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_list_items, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :item_recording_id, null: false
      t.datetime :created_at, null: false
    end

    add_index :recording_studio_list_items, :item_recording_id
    add_foreign_key :recording_studio_list_items, :recording_studio_recordings,
                    column: :item_recording_id, on_delete: :restrict
  end
end
