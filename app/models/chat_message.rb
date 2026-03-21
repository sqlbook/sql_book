# frozen_string_literal: true

class ChatMessage < ApplicationRecord
  MAX_IMAGE_COUNT = 6
  MAX_IMAGE_SIZE = 25.megabytes
  ALLOWED_IMAGE_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze

  class Roles
    USER = 1
    ASSISTANT = 2
    SYSTEM = 3
  end

  class Statuses
    PENDING = 1
    COMPLETED = 2
    FAILED = 3
  end

  belongs_to :chat_thread
  belongs_to :user, optional: true

  has_many :chat_action_requests, dependent: :nullify, inverse_of: :chat_message
  has_many :source_chat_action_requests,
           class_name: 'ChatActionRequest',
           foreign_key: :source_message_id,
           dependent: :nullify,
           inverse_of: :source_message
  has_many :source_query_references,
           class_name: 'ChatQueryReference',
           foreign_key: :source_message_id,
           dependent: :nullify,
           inverse_of: :source_message
  has_many :result_query_references,
           class_name: 'ChatQueryReference',
           foreign_key: :result_message_id,
           dependent: :nullify,
           inverse_of: :result_message
  has_many_attached :images

  validates :role, inclusion: { in: [Roles::USER, Roles::ASSISTANT, Roles::SYSTEM] }
  validates :status, inclusion: { in: [Statuses::PENDING, Statuses::COMPLETED, Statuses::FAILED] }
  validate :content_or_images_present
  validate :images_are_supported

  def user?
    role == Roles::USER
  end

  def assistant?
    role == Roles::ASSISTANT
  end

  def system?
    role == Roles::SYSTEM
  end

  def role_name
    {
      Roles::USER => 'user',
      Roles::ASSISTANT => 'assistant',
      Roles::SYSTEM => 'system'
    }.fetch(role, 'assistant')
  end

  def status_name
    {
      Statuses::PENDING => 'pending',
      Statuses::COMPLETED => 'completed',
      Statuses::FAILED => 'failed'
    }.fetch(status, 'completed')
  end

  private

  def content_or_images_present
    return if content.present? || images.attachments.any?

    errors.add(:base, 'Message content or at least one image is required')
  end

  def images_are_supported # rubocop:disable Metrics/AbcSize
    return if images.blank?

    errors.add(:images, "cannot exceed #{MAX_IMAGE_COUNT} files") if images.attachments.size > MAX_IMAGE_COUNT

    images.attachments.each do |attachment|
      blob = attachment.blob
      next unless blob

      errors.add(:images, 'must be PNG, JPG, WEBP, or GIF') unless ALLOWED_IMAGE_TYPES.include?(blob.content_type.to_s)
      errors.add(:images, 'must be 25MB or smaller') if blob.byte_size > MAX_IMAGE_SIZE
    end
  end
end
