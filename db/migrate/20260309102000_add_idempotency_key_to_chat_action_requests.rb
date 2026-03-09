# frozen_string_literal: true

class AddIdempotencyKeyToChatActionRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_action_requests, :idempotency_key, :string
    add_index :chat_action_requests, :idempotency_key, unique: true
  end
end
