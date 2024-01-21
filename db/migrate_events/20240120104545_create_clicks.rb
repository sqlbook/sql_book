# frozen_string_literal: true

class CreateClicks < ActiveRecord::Migration[7.1]
  def up # rubocop:disable Metrics/MethodLength
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

    # Enable RLS for this table
    execute 'ALTER TABLE clicks ENABLE ROW LEVEL SECURITY;'
    # Ensure the table owner is also subject to RLS
    execute 'ALTER TABLE clicks FORCE ROW LEVEL SECURITY;'
    # Set a policy on this table to scope the requests to the data source
    execute "CREATE POLICY clicks_policy ON clicks FOR SELECT USING (data_source_uuid = current_setting('app.current_data_source_uuid')::uuid);" # rubocop:disable Layout/LineLength
  end

  def down
    drop_table :clicks
  end
end
