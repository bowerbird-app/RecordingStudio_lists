# frozen_string_literal: true

class CreateRecordingStudioLists < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_lists, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.text :description
      t.datetime :created_at, null: false
    end
  end
end
