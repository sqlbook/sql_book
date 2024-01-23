# frozen_string_literal: true

class CreateDataSources < ActiveRecord::Migration[7.1]
  def change
    create_table :data_sources do |t|
      t.string :url, null: false
      t.uuid :external_uuid, null: false, default: 'gen_random_uuid()'
      t.datetime :verified_at

      t.belongs_to :workspace

      t.timestamps
    end

    add_index :data_sources, :url, unique: true
    add_index :data_sources, :external_uuid, unique: true
  end
end
