# frozen_string_literal: true

require 'digest'
require 'json'

class RefactorChatActionRequestLifecycle < ActiveRecord::Migration[8.0]
  class MigrationChatActionRequest < ApplicationRecord
    self.table_name = 'chat_action_requests'
  end

  CONTEXT_KEYS = %w[workspace_id thread_id message_id].freeze

  # rubocop:disable Rails/BulkChangeTable
  def up
    add_reference :chat_action_requests,
                  :source_message,
                  foreign_key: { to_table: :chat_messages },
                  type: :bigint,
                  index: false
    add_column :chat_action_requests, :action_fingerprint, :string
    add_column :chat_action_requests, :superseded_at, :datetime

    backfill_lifecycle_columns!

    add_index :chat_action_requests, :action_fingerprint
    add_index :chat_action_requests,
              %i[chat_thread_id requested_by_id action_fingerprint],
              unique: true,
              where: 'status = 1 AND superseded_at IS NULL',
              name: 'idx_chat_action_requests_active_pending_fingerprint'
  end

  def down
    remove_index :chat_action_requests, name: 'idx_chat_action_requests_active_pending_fingerprint'
    remove_index :chat_action_requests, :action_fingerprint
    remove_column :chat_action_requests, :superseded_at
    remove_column :chat_action_requests, :action_fingerprint
    remove_reference :chat_action_requests, :source_message, foreign_key: { to_table: :chat_messages }
  end
  # rubocop:enable Rails/BulkChangeTable

  private

  def backfill_lifecycle_columns!
    MigrationChatActionRequest.reset_column_information

    say_with_time 'Backfilling source_message_id and action_fingerprint for chat action requests' do
      MigrationChatActionRequest.find_each do |request|
        payload = request.payload.to_h.except(*CONTEXT_KEYS)
        request.update_columns( # rubocop:disable Rails/SkipsModelValidations
          source_message_id: request.chat_message_id,
          action_fingerprint: fingerprint_for(request:, payload:)
        )
      end
    end
  end

  def fingerprint_for(request:, payload:)
    stable_payload = deep_sorted_value(payload)
    Digest::SHA256.hexdigest(
      "#{request.chat_thread_id}:#{request.requested_by_id}:#{request.action_type}:#{JSON.generate(stable_payload)}"
    )
  end

  def deep_sorted_value(value)
    case value
    when Hash
      value.to_h.sort.to_h { |key, child| [key.to_s, deep_sorted_value(child)] }
    when Array
      value.map { |child| deep_sorted_value(child) }
    else
      value
    end
  end
end
