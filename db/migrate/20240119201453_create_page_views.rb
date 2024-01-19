# frozen_string_literal: true

class CreatePageViews < ActiveRecord::Migration[7.1]
  def change
    create_table :page_views do |t|
      t.uuid :data_source_uuid, null: false
      t.uuid :session_uuid, null: false
      t.uuid :visitor_uuid, null: false
      t.bigint :timestamp, null: false
      t.string :url, null: false

      t.belongs_to :data_source

      t.timestamps
    end
  end
end
