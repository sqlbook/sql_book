# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OneTimePasswordMailer, type: :mailer do
  let(:email) { "#{SecureRandom.base36}@email.com" }
  let(:token) { '123456' }

  describe '#login' do
    subject { described_class.login(email:, token:) }

    it 'renders the correct headers' do
      expect(subject.subject).to eq 'Your log-in code for Sqlbook'
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

    it 'renders the logo with an absolute asset URL' do
      expect(subject.body).to include('http://localhost:3000/assets/logo')
    end
  end

  describe '#signup' do
    subject { described_class.signup(email:, token:) }

    it 'renders the correct headers' do
      expect(subject.subject).to eq 'Your sign-up code for Sqlbook'
      expect(subject.to).to eq [email]
      expect(subject.from).to eq ['noreply@sqlbook.com']
    end

    it 'includes the token in the email' do
      expect(subject.body).to include(token)
    end

    it 'renders the magic link in the email' do
      url_escaped_email = email.sub('@', '%40')
      expect(subject.body).to include('http://localhost:3000/auth/signup/magic_link?')
      expect(subject.body).to include("email=#{url_escaped_email}")
      expect(subject.body).to include('one_time_password_1=1')
      expect(subject.body).to include('one_time_password_2=2')
      expect(subject.body).to include('one_time_password_3=3')
      expect(subject.body).to include('one_time_password_4=4')
      expect(subject.body).to include('one_time_password_5=5')
      expect(subject.body).to include('one_time_password_6=6')
      expect(subject.body).to include('accept_terms=1')
    end

    it 'includes signup profile fields in the magic link when provided' do
      mail = described_class.signup(email:, token:, magic_link_params: { first_name: 'Chris', last_name: 'Pattison' })

      expect(mail.body).to include('first_name=Chris')
      expect(mail.body).to include('last_name=Pattison')
    end
  end
end
