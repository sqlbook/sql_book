# frozen_string_literal: true

class ChatPendingFollowUp < ApplicationRecord
  class Statuses
    ACTIVE = 1
    RESOLVED = 2
    CANCELED = 3
    SUPERSEDED = 4
  end

  belongs_to :workspace
  belongs_to :chat_thread
  belongs_to :created_by,
             class_name: 'User',
             inverse_of: :chat_pending_follow_ups
  belongs_to :source_message,
             class_name: 'ChatMessage',
             optional: true,
             inverse_of: :source_chat_pending_follow_ups

  validates :kind, presence: true
  validates :domain, presence: true
  validates :status, inclusion: {
    in: [
      Statuses::ACTIVE,
      Statuses::RESOLVED,
      Statuses::CANCELED,
      Statuses::SUPERSEDED
    ]
  }

  scope :active, -> { where(status: Statuses::ACTIVE, superseded_at: nil) }
  scope :recent_first, -> { order(updated_at: :desc, id: :desc) }

  def active?
    status == Statuses::ACTIVE && superseded_at.blank?
  end

  def serialized_payload
    {
      'id' => id,
      'kind' => kind,
      'domain' => domain,
      'target_type' => target_type,
      'target_id' => target_id,
      'status' => status_name,
      'payload' => payload.to_h.deep_stringify_keys,
      'source_message_id' => source_message_id,
      'created_at' => created_at&.iso8601,
      'updated_at' => updated_at&.iso8601
    }.compact
  end

  def status_name
    {
      Statuses::ACTIVE => 'active',
      Statuses::RESOLVED => 'resolved',
      Statuses::CANCELED => 'canceled',
      Statuses::SUPERSEDED => 'superseded'
    }.fetch(status, 'active')
  end
end
