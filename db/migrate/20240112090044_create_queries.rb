# frozen_string_literal: true

class CreateQueries < ActiveRecord::Migration[7.1]
  def change
    create_table :queries do |t|
      t.string :name
      t.string :query, null: false
      t.boolean :saved, default: false, null: false

      t.belongs_to :data_source

      t.timestamps
    end
  end
end
