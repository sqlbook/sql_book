# frozen_string_literal: true

class CreateDashboards < ActiveRecord::Migration[7.1]
  def change
    create_table :dashboards do |t|
      t.string :name, null: false

      t.bigint :author_id, null: false

      t.belongs_to :workspace

      t.timestamps
    end
  end
end
