# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChatMessage, type: :model do
  let(:chat_thread) { create(:chat_thread) }
  let(:author) { create(:user) }

  describe 'validations' do
    it 'requires content or at least one image' do
      message = described_class.new(
        chat_thread:,
        user: author,
        role: ChatMessage::Roles::USER,
        status: ChatMessage::Statuses::COMPLETED,
        content: nil
      )

      expect(message).not_to be_valid
      expect(message.errors.full_messages.to_sentence).to include('Message content or at least one image is required')
    end

    it 'allows a plain text message' do
      message = described_class.new(
        chat_thread:,
        user: author,
        role: ChatMessage::Roles::USER,
        status: ChatMessage::Statuses::COMPLETED,
        content: 'Hello team'
      )

      expect(message).to be_valid
    end

    it 'rejects unsupported image content types' do
      message = described_class.new(
        chat_thread:,
        user: author,
        role: ChatMessage::Roles::USER,
        status: ChatMessage::Statuses::COMPLETED,
        content: 'Image upload'
      )

      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('not an image'),
        filename: 'notes.txt',
        content_type: 'text/plain'
      )
      message.images.attach(blob)

      expect(message).not_to be_valid
      expect(message.errors[:images]).to include('must be PNG, JPG, WEBP, or GIF')
    end

    it 'rejects oversized images' do
      message = described_class.new(
        chat_thread:,
        user: author,
        role: ChatMessage::Roles::USER,
        status: ChatMessage::Statuses::COMPLETED,
        content: 'Big image upload'
      )

      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('x' * (ChatMessage::MAX_IMAGE_SIZE + 1)),
        filename: 'big.png',
        content_type: 'image/png'
      )
      message.images.attach(blob)

      expect(message).not_to be_valid
      expect(message.errors[:images]).to include('must be 25MB or smaller')
    end
  end
end
