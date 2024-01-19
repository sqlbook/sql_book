# frozen_string_literal: true

class CreateClicks < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :clicks do |t|
      t.uuid :data_source_uuid, null: false
      t.uuid :session_uuid, null: false
      t.uuid :visitor_uuid, null: false
      t.bigint :timestamp, null: false
      t.integer :coordinates_x, null: false
      t.integer :coordinates_y, null: false
      t.string :xpath, null: false
      t.string :inner_text
      t.string :attribute_id
      t.string :attribute_class

      t.belongs_to :data_source

      t.timestamps
    end
  end
end
