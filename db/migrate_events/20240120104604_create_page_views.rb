# frozen_string_literal: true

class CreatePageViews < ActiveRecord::Migration[7.1]
  def up # rubocop:disable Metrics/MethodLength
    create_table :page_views do |t|
      t.uuid :data_source_uuid, null: false
      t.uuid :session_uuid, null: false
      t.uuid :visitor_uuid, null: false
      t.bigint :timestamp, null: false
      t.string :url, null: false

      t.belongs_to :data_source

      t.timestamps
    end

    # Enable RLS for this table
    execute 'ALTER TABLE page_views ENABLE ROW LEVEL SECURITY;'
    # Ensure the table owner is also subject to RLS
    execute 'ALTER TABLE page_views FORCE ROW LEVEL SECURITY;'
    # Set a policy on this table to scope the requests to the data source
    execute "CREATE POLICY page_views_policy ON page_views FOR SELECT USING (data_source_uuid = current_setting('app.current_data_source_uuid')::uuid);" # rubocop:disable Layout/LineLength
  end

  def down
    drop_table :page_views
  end
end
