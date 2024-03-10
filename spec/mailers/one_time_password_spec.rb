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
      expect(subject.from).to eq ['noreply@sqlbook.com']
    end

    it 'includes the token in the email' do
      expect(subject.body).to include(token)
    end

    it 'renders the magic link in the email' do
      url_escaped_email = email.sub('@', '%40')
      expect(subject.body).to include("http://localhost:3000/auth/login/magic_link?email=#{url_escaped_email}" \
                                      '&amp;one_time_password_1=1' \
                                      '&amp;one_time_password_2=2' \
                                      '&amp;one_time_password_3=3' \
                                      '&amp;one_time_password_4=4' \
                                      '&amp;one_time_password_5=5' \
                                      '&amp;one_time_password_6=6')
    end
  end

  describe '#signup' do
    subject { described_class.signup(email:, token:) }

    it 'renders the correct headers' do
      expect(subject.subject).to eq 'Your sign-up code for sql_book'
      expect(subject.to).to eq [email]
      expect(subject.from).to eq ['noreply@sqlbook.com']
    end

    it 'includes the token in the email' do
      expect(subject.body).to include(token)
    end

    it 'renders the magic link in the email' do
      url_escaped_email = email.sub('@', '%40')
      expect(subject.body).to include("http://localhost:3000/auth/signup/magic_link?email=#{url_escaped_email}" \
                                      '&amp;one_time_password_1=1' \
                                      '&amp;one_time_password_2=2' \
                                      '&amp;one_time_password_3=3' \
                                      '&amp;one_time_password_4=4' \
                                      '&amp;one_time_password_5=5' \
                                      '&amp;one_time_password_6=6')
    end
  end
end
