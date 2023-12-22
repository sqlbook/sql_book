# frozen_string_literal: true

class CreateDataSources < ActiveRecord::Migration[7.1]
  def change
    create_table :data_sources do |t|
      t.string :url, null: false
      t.datetime :verified_at

      t.belongs_to :user

      t.timestamps
    end

    add_index :data_sources, :url, unique: true
  end
end
