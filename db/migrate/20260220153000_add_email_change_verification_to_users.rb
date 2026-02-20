# frozen_string_literal: true

class AddEmailChangeVerificationToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :pending_email, :string
    add_column :users, :email_change_verification_token, :string
    add_column :users, :email_change_verification_sent_at, :datetime

    add_index :users, :email_change_verification_token, unique: true
  end
end
