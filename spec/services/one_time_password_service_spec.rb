# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OneTimePasswordService do
  let(:email) { "#{SecureRandom.base36}@email.com" }
  let(:auth_type) { :login }

  let(:token_stub) { '123456' }
  let(:mailer_stub) { double(:mailer_stub) }

  let(:instance) { described_class.new(email:, auth_type:) }

  before do
    allow(OneTimePasswordMailer).to receive(:login).and_call_original
    allow(OneTimePasswordMailer).to receive(:signup).and_call_original

    allow(instance).to receive(:token).and_return(token_stub)
  end

  describe '#create!' do
    subject { instance.create! }

    context 'when the token does not exist' do
      it 'sends an email to the email with the token' do
        subject
        expect(OneTimePasswordMailer).to have_received(:login).with(email:, token: token_stub)
      end

      it 'creates the OneTimePassword record' do
        expect { subject }.to change { OneTimePassword.exists?(email:) }.from(false).to(true)
      end
    end

    context 'when the token exists' do
      before do
        create(:one_time_password, email:, token: '654321')
      end

      it 'sends a replacement code email' do
        subject
        expect(OneTimePasswordMailer).to have_received(:login).with(email:, token: token_stub)
      end

      it 'does not create another OneTimePassword record' do
        expect { subject }.not_to change { OneTimePassword.count }
      end

      it 'rotates the stored token' do
        expect { subject }
          .to change { OneTimePassword.find_by(email:).token }
          .from('654321')
          .to(token_stub)
      end
    end

    context 'when the auth type is :signup' do
      let(:auth_type) { :signup }

      it 'sends a signup email' do
        subject
        expect(OneTimePasswordMailer).to have_received(:signup).with(email:, token: token_stub, magic_link_params: {})
      end
    end
  end

  describe '#resend!' do
    subject { instance.resend! }

    context 'when the token does not exist' do
      it 'raises a RecordNotFound exception' do
        expect { subject }.to raise_error { ActiveRecord::RecordNotFound }
      end
    end

    context 'when the token does exist' do
      before do
        create(:one_time_password, email:, token: '654321')
      end

      it 'does not create a new token' do
        expect { subject }.not_to change { OneTimePassword.count }
      end

      it 'sends a replacement code' do
        subject
        expect(OneTimePasswordMailer).to have_received(:login).with(email:, token: token_stub)
      end

      it 'rotates the stored token' do
        expect { subject }
          .to change { OneTimePassword.find_by(email:).token }
          .from('654321')
          .to(token_stub)
      end
    end
  end

  describe '#verify' do
    let(:token) { '123456' }

    subject { instance.verify(token:) }

    context 'when there is no stored token' do
      it 'returns false' do
        expect(subject).to eq(false)
      end
    end

    context 'when there is a stored token, but the provided token is wrong' do
      let(:token) { '847682' }

      before do
        instance.create!
      end

      it 'returns false' do
        expect(subject).to eq(false)
      end

      it 'does not delete the record' do
        expect { subject }.not_to change { OneTimePassword.exists?(email:) }
      end
    end

    context 'when there is a stored token and it matches the provided token' do
      let(:token) { '123456' }

      before do
        instance.create!
      end

      it 'returns true' do
        expect(subject).to eq(true)
      end

      it 'deletes the record' do
        expect { subject }.to change { OneTimePassword.exists?(email:) }.from(true).to(false)
      end
    end
  end
end
