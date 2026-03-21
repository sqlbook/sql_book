# frozen_string_literal: true

class CreateChatQueryReferences < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_query_references do |t|
      t.references :chat_thread, null: false, foreign_key: true
      t.references :source_message, foreign_key: { to_table: :chat_messages }
      t.references :result_message, foreign_key: { to_table: :chat_messages }
      t.references :data_source, foreign_key: true
      t.references :saved_query, foreign_key: { to_table: :queries }
      t.text :original_question
      t.text :sql
      t.string :current_name
      t.jsonb :name_aliases, null: false, default: []
      t.integer :row_count
      t.jsonb :columns, null: false, default: []
      t.timestamps
    end

    add_index :chat_query_references,
              %i[chat_thread_id updated_at id],
              name: 'index_chat_query_references_on_thread_recency'
    add_index :chat_query_references,
              %i[chat_thread_id saved_query_id],
              unique: true,
              where: 'saved_query_id IS NOT NULL',
              name: 'index_chat_query_references_on_thread_and_saved_query'
  end
end
