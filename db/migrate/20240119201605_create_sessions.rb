# frozen_string_literal: true

class CreateSessions < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    create_table :sessions do |t|
      t.uuid :data_source_uuid, null: false
      t.uuid :session_uuid, null: false
      t.uuid :visitor_uuid, null: false
      t.bigint :timestamp, null: false
      t.integer :viewport_x, null: false
      t.integer :viewport_y, null: false
      t.integer :device_x, null: false
      t.integer :device_y, null: false
      t.string :referrer
      t.string :locale
      t.string :useragent
      t.string :browser
      t.string :timezone
      t.string :country_code
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign
      t.string :utm_content
      t.string :utm_term

      t.belongs_to :data_source

      t.timestamps
    end
  end
end
