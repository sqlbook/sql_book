# frozen_string_literal: true

class AddEmailChangeVerificationToUsers < ActiveRecord::Migration[7.1]
  def change
    change_table :users, bulk: true do |table|
      table.string :pending_email
      table.string :email_change_verification_token
      table.datetime :email_change_verification_sent_at
    end

    add_index :users, :email_change_verification_token, unique: true
  end
end
