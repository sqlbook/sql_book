# frozen_string_literal: true

class AddMetadataToChatThreads < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_threads, :metadata, :jsonb, null: false, default: {}
  end
end
