# frozen_string_literal: true

class ChatActionRequest < ApplicationRecord
  CONFIRMATION_WINDOW = 15.minutes

  class Statuses
    PENDING_CONFIRMATION = 1
    EXECUTED = 2
    CANCELED = 3
    FORBIDDEN = 4
    VALIDATION_ERROR = 5
    EXECUTION_ERROR = 6
  end

  belongs_to :chat_thread
  belongs_to :chat_message, optional: true

  belongs_to :requested_by,
             class_name: 'User',
             optional: true,
             inverse_of: :chat_action_requests

  validates :action_type, presence: true
  validates :status, inclusion: {
    in: [
      Statuses::PENDING_CONFIRMATION,
      Statuses::EXECUTED,
      Statuses::CANCELED,
      Statuses::FORBIDDEN,
      Statuses::VALIDATION_ERROR,
      Statuses::EXECUTION_ERROR
    ]
  }
  validates :confirmation_token, uniqueness: true, allow_nil: true
  validates :idempotency_key, uniqueness: true, allow_nil: true, if: :idempotency_supported?

  before_validation :assign_confirmation_defaults, on: :create

  scope :pending_confirmation, -> { where(status: Statuses::PENDING_CONFIRMATION) }

  def pending_confirmation?
    status == Statuses::PENDING_CONFIRMATION
  end

  def expired?
    confirmation_expires_at.present? && confirmation_expires_at < Time.current
  end

  def status_name
    {
      Statuses::PENDING_CONFIRMATION => 'requires_confirmation',
      Statuses::EXECUTED => 'executed',
      Statuses::CANCELED => 'canceled',
      Statuses::FORBIDDEN => 'forbidden',
      Statuses::VALIDATION_ERROR => 'validation_error',
      Statuses::EXECUTION_ERROR => 'execution_error'
    }.fetch(status, 'execution_error')
  end

  private

  def assign_confirmation_defaults
    return unless pending_confirmation?

    self.confirmation_token ||= SecureRandom.hex(20)
    self.confirmation_expires_at ||= CONFIRMATION_WINDOW.from_now
  end

  def idempotency_supported?
    self.class.column_names.include?('idempotency_key')
  end
end
