# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OneTimePasswordMailer, type: :mailer do
  let(:email) { "#{SecureRandom.base36}@email.com" }
  let(:token) { '123456' }

  describe '#login' do
    subject { described_class.login(email:, token:) }

    it 'renders the correct headers' do
      expect(subject.subject).to eq 'Your log-in code for sql_book'
      expect(subject.to).to eq [email]
      expect(subject.from).to eq ['hello@sqlbook.com']
    end

    it 'includes the token in the email' do
      expect(subject.body).to include(token)
    end
  end

  describe '#signup' do
    subject { described_class.signup(email:, token:) }

    it 'renders the correct headers' do
      expect(subject.subject).to eq 'Your sign-up code for sql_book'
      expect(subject.to).to eq [email]
      expect(subject.from).to eq ['hello@sqlbook.com']
    end

    it 'includes the token in the email' do
      expect(subject.body).to include(token)
    end
  end
end
