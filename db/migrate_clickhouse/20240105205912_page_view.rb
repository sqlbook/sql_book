# frozen_string_literal: true

class PageView < ActiveRecord::Migration[7.1]
  def change
    create_table :page_views, id: false, options: 'MergeTree ORDER BY (data_source_uuid, toDate(timestamp))' do |t|
      t.uuid    :uuid,             null: false
      t.uuid    :data_source_uuid, null: false
      t.uuid    :session_uuid,     null: false
      t.uuid    :visitor_uuid,     null: false
      t.bigint  :timestamp,        null: false
      t.string  :url,              null: false
    end
  end
end
