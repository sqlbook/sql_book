# frozen_string_literal: true

class CreateOneTimePasswords < ActiveRecord::Migration[7.1]
  def change
    create_table :one_time_passwords do |t|
      t.string :email
      t.string :token

      t.timestamps
    end

    add_index :one_time_passwords, :email, unique: true
  end
end
