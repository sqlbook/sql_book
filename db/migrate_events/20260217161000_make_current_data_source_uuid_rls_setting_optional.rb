# frozen_string_literal: true

class MakeCurrentDataSourceUuidRlsSettingOptional < ActiveRecord::Migration[7.1]
  def up
    update_policy(table: :clicks, policy: :clicks_policy)
    update_policy(table: :page_views, policy: :page_views_policy)
    update_policy(table: :sessions, policy: :sessions_policy)
  end

  def down
    restore_policy(table: :clicks, policy: :clicks_policy)
    restore_policy(table: :page_views, policy: :page_views_policy)
    restore_policy(table: :sessions, policy: :sessions_policy)
  end

  private

  def update_policy(table:, policy:)
    execute <<~SQL.squish
      DROP POLICY IF EXISTS #{policy} ON #{table};
      CREATE POLICY #{policy} ON #{table}
      FOR SELECT USING (data_source_uuid = current_setting('app.current_data_source_uuid', true)::uuid)
    SQL
  end

  def restore_policy(table:, policy:)
    execute <<~SQL.squish
      DROP POLICY IF EXISTS #{policy} ON #{table};
      CREATE POLICY #{policy} ON #{table}
      FOR SELECT USING (data_source_uuid = current_setting('app.current_data_source_uuid')::uuid)
    SQL
  end
end
