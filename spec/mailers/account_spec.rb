# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountMailer, type: :mailer do
  describe '#verify_email_change' do
    let(:user) { create(:user, email: 'hello@sitelabs.ai', pending_email: 'new@sitelabs.ai') }
    let(:token) { 'verify-token' }

    subject { described_class.verify_email_change(user:, token:) }

    it 'renders the correct headers' do
      expect(subject.subject).to eq 'Confirm your email change on sqlbook.'
      expect(subject.to).to eq [user.email]
      expect(subject.from).to eq ['noreply@sqlbook.com']
    end

    it 'includes the verification link' do
      expect(subject.body).to include("/app/account-settings/verify-email/#{token}")
    end

    it 'includes current and new email addresses' do
      expect(subject.body).to include('hello@sitelabs.ai')
      expect(subject.body).to include('new@sitelabs.ai')
    end

    it 'includes expiration guidance' do
      expect(subject.body).to include('expire in 1 hour')
    end
  end
end
