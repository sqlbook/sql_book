# frozen_string_literal: true

class CreateMembers < ActiveRecord::Migration[7.1]
  def change
    create_table :members do |t|
      t.integer :role

      t.belongs_to :user
      t.belongs_to :workspace

      t.timestamps
    end
  end
end
