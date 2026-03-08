# frozen_string_literal: true

class ChatThread < ApplicationRecord
  belongs_to :workspace

  belongs_to :created_by,
             class_name: 'User',
             optional: true,
             inverse_of: :chat_threads

  has_many :chat_messages,
           -> { order(:id) },
           dependent: :destroy,
           inverse_of: :chat_thread

  has_many :chat_action_requests,
           -> { order(:id) },
           dependent: :destroy,
           inverse_of: :chat_thread

  scope :active, -> { where(archived_at: nil) }
  scope :with_messages, -> { joins(:chat_messages).distinct }

  validates :title, length: { maximum: 255 }, allow_blank: true

  def self.active_for(workspace:, user:)
    active.where(workspace:).order(updated_at: :desc, id: :desc).first || create!(workspace:, created_by: user)
  end
end
