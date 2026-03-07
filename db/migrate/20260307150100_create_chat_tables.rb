# frozen_string_literal: true

class CreateChatTables < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_threads do |t|
      t.references :workspace, null: false, foreign_key: true, type: :bigint
      t.references :created_by,
                   null: true,
                   foreign_key: { to_table: :users, on_delete: :nullify },
                   type: :bigint
      t.string :title
      t.datetime :archived_at
      t.timestamps
    end

    create_table :chat_messages do |t|
      t.references :chat_thread, null: false, foreign_key: true, type: :bigint
      t.references :user,
                   null: true,
                   foreign_key: { to_table: :users, on_delete: :nullify },
                   type: :bigint
      t.integer :role, null: false
      t.integer :status, null: false, default: 2
      t.text :content
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    create_table :chat_action_requests do |t|
      t.references :chat_thread, null: false, foreign_key: true, type: :bigint
      t.references :chat_message, null: true, foreign_key: true, type: :bigint
      t.references :requested_by,
                   null: true,
                   foreign_key: { to_table: :users, on_delete: :nullify },
                   type: :bigint
      t.string :action_type, null: false
      t.integer :status, null: false, default: 1
      t.jsonb :payload, null: false, default: {}
      t.jsonb :result_payload, null: false, default: {}
      t.string :confirmation_token
      t.datetime :confirmation_expires_at
      t.datetime :executed_at
      t.timestamps
    end

    add_index :chat_action_requests, :confirmation_token, unique: true
  end
end
