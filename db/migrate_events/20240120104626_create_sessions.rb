# frozen_string_literal: true

class CreateSessions < ActiveRecord::Migration[7.1]
  def up # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
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

    # Enable RLS for this table
    execute 'ALTER TABLE sessions ENABLE ROW LEVEL SECURITY'
    # Ensure the table owner is also subject to RLS
    execute 'ALTER TABLE sessions FORCE ROW LEVEL SECURITY'
    # Set a policy on this table to scope the requests to the data source
    execute "CREATE POLICY sessions_policy ON sessions FOR SELECT USING (data_source_uuid = current_setting('app.current_data_source_uuid')::uuid);" # rubocop:disable Layout/LineLength
  end

  def down
    drop_table :sessions
  end
end
