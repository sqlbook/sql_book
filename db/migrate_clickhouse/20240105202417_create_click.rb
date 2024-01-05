# frozen_string_literal: true

class CreateClick < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :clicks, id: false, options: 'MergeTree ORDER BY (data_source_uuid, toDate(timestamp))' do |t|
      t.uuid    :uuid,             null: false
      t.uuid    :data_source_uuid, null: false
      t.uuid    :session_uuid,     null: false
      t.uuid    :visitor_uuid,     null: false
      t.bigint  :timestamp,        null: false
      t.integer :coordinates_x,    null: false
      t.integer :coordinates_y,    null: false
      t.string  :xpath,            null: false
      t.string  :inner_text,       null: true
      t.string  :attribute_id,     null: true
      t.string  :attribute_class,  null: true
    end
  end
end
