# frozen_string_literal: true

class CreateClicks < ActiveRecord::Migration[7.1]
  def up
    create_table :clicks, id: :uuid, primary_key: :uuid do |t|
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
    end

    add_index :clicks, :data_source_uuid

    # Enable RLS for this table
    execute <<-SQL.squish
      ALTER TABLE clicks
      ENABLE ROW LEVEL SECURITY
    SQL

    # Ensure the table owner is also subject to RLS
    execute <<-SQL.squish
      ALTER TABLE clicks
      FORCE ROW LEVEL SECURITY
    SQL

    # Set a policy on this table to scope the requests to the data source
    execute <<-SQL.squish
      CREATE POLICY clicks_policy ON clicks
      FOR SELECT USING (data_source_uuid = current_setting('app.current_data_source_uuid')::uuid)
    SQL
  end

  def down
    drop_table :clicks
  end
end
