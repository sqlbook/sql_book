# frozen_string_literal: true

class CreateMembers < ActiveRecord::Migration[7.1]
  def change
    create_table :members do |t|
      t.integer :role, null: false
      t.integer :status, null: false
      t.string :invitation

      t.bigint :invited_by_id

      t.belongs_to :user
      t.belongs_to :workspace

      t.timestamps
    end
  end
end
