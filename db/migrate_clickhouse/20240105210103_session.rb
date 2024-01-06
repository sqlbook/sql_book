# frozen_string_literal: true

class Session < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    create_table :sessions, id: false, options: 'MergeTree ORDER BY (data_source_uuid, toDate(timestamp))' do |t|
      t.uuid    :uuid,             null: false
      t.uuid    :data_source_uuid, null: false
      t.uuid    :session_uuid,     null: false
      t.uuid    :visitor_uuid,     null: false
      t.bigint  :timestamp,        null: false
      t.integer :viewport_x,       null: false
      t.integer :viewport_y,       null: false
      t.integer :device_x,         null: false
      t.integer :device_y,         null: false
      t.string  :referrer,         null: true
      t.string  :locale,           null: true
      t.string  :useragent,        null: true
      t.string  :browser,          null: true
      t.string  :timezone,         null: true
      t.string  :country_code,     null: true
      t.string  :utm_source,       null: true
      t.string  :utm_medium,       null: true
      t.string  :utm_campaign,     null: true
      t.string  :utm_content,      null: true
      t.string  :utm_term,         null: true
    end
  end
end
