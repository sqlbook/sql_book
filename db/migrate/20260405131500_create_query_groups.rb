# frozen_string_literal: true

class CreateQueryGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :query_groups do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :query_groups,
              'workspace_id, lower(name)',
              unique: true,
              name: 'index_query_groups_on_workspace_id_and_lower_name'

    create_table :query_group_memberships do |t|
      t.references :query, null: false, foreign_key: true
      t.references :query_group, null: false, foreign_key: true

      t.timestamps
    end

    add_index :query_group_memberships, %i[query_id query_group_id], unique: true
  end
end
