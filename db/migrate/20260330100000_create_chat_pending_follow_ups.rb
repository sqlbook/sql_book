# frozen_string_literal: true

class CreateChatPendingFollowUps < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_pending_follow_ups do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :chat_thread, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :source_message, null: true, foreign_key: { to_table: :chat_messages }
      t.integer :status, null: false, default: 1
      t.string :kind, null: false
      t.string :domain, null: false
      t.string :target_type
      t.bigint :target_id
      t.json :payload, null: false, default: {}
      t.datetime :resolved_at
      t.datetime :superseded_at
      t.timestamps
    end

    add_index :chat_pending_follow_ups,
              %i[chat_thread_id created_by_id],
              where: 'status = 1 AND superseded_at IS NULL',
              unique: true,
              name: 'index_chat_pending_follow_ups_on_active_thread_actor'
    add_index :chat_pending_follow_ups,
              %i[chat_thread_id kind status],
              name: 'index_chat_pending_follow_ups_on_thread_kind_status'
  end
end
