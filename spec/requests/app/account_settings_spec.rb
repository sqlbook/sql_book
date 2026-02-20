# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::AccountSettings', type: :request do
  describe 'GET /app/account-settings' do
    let(:user) { create(:user) }

    context 'when user is not authenticated' do
      it 'redirects to login' do
        get '/app/account-settings'

        expect(response).to redirect_to(auth_login_index_path)
      end
    end

    context 'when user is authenticated' do
      before { sign_in(user) }

      it 'renders the page' do
        get '/app/account-settings'

        expect(response).to have_http_status(:ok)
      end

      it 'does not render workspace breadcrumbs' do
        get '/app/account-settings'

        expect(response.body).not_to have_selector('.breadcrumbs')
      end
    end
  end

  describe 'PATCH /app/account-settings' do
    let(:user) { create(:user, first_name: 'Chris', last_name: 'Pattison', email: 'hello@sitelabs.ai') }

    before { sign_in(user) }

    context 'when only name fields are changed' do
      let(:params) { { first_name: 'Christopher', last_name: 'Pattison', email: user.email } }

      it 'updates the user profile' do
        patch '/app/account-settings', params: params

        expect(user.reload.first_name).to eq('Christopher')
        expect(user.reload.last_name).to eq('Pattison')
        expect(user.reload.email).to eq('hello@sitelabs.ai')
      end

      it 'sets a success toast' do
        patch '/app/account-settings', params: params

        expect(flash[:toast]).to include(
          type: 'success',
          title: I18n.t('toasts.account_settings.updated.title'),
          body: I18n.t('toasts.account_settings.updated.body')
        )
      end
    end

    context 'when email is changed' do
      let(:mail_delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }
      let(:params) { { first_name: 'Christopher', last_name: 'Pattison', email: 'new@sitelabs.ai' } }

      before do
        allow(AccountMailer).to receive(:verify_email_change).and_return(mail_delivery)
      end

      it 'keeps current email unchanged until verification' do
        patch '/app/account-settings', params: params

        expect(user.reload.email).to eq('hello@sitelabs.ai')
        expect(user.pending_email).to eq('new@sitelabs.ai')
        expect(user.email_change_verification_token).to be_present
        expect(user.email_change_verification_sent_at).to be_present
      end

      it 'sends a verification email to the current email address' do
        patch '/app/account-settings', params: params

        expect(AccountMailer).to have_received(:verify_email_change).with(
          user: user,
          token: user.reload.email_change_verification_token
        )
      end

      it 'sets a verification-pending toast' do
        patch '/app/account-settings', params: params

        expect(flash[:toast]).to include(
          type: 'information',
          title: I18n.t('toasts.account_settings.email_verification_pending.title'),
          body: I18n.t('toasts.account_settings.email_verification_pending.body')
        )
      end
    end

    context 'when requested email is already in use' do
      let!(:existing_user) { create(:user, email: 'existing@sitelabs.ai') }
      let(:params) { { first_name: 'Chris', last_name: 'Pattison', email: existing_user.email } }

      it 'does not queue an email change request' do
        patch '/app/account-settings', params: params

        expect(user.reload.pending_email).to be_nil
        expect(user.email_change_verification_token).to be_nil
      end

      it 'sets an unavailable email toast' do
        patch '/app/account-settings', params: params

        expect(flash[:toast]).to include(
          type: 'error',
          title: I18n.t('toasts.account_settings.email_unavailable.title'),
          body: I18n.t('toasts.account_settings.email_unavailable.body')
        )
      end
    end
  end

  describe 'GET /app/account-settings/verify-email/:token' do
    let(:user) do
      create(
        :user,
        email: 'hello@sitelabs.ai',
        pending_email: 'verified@sitelabs.ai',
        email_change_verification_token: 'verify-token',
        email_change_verification_sent_at: sent_at
      )
    end

    context 'when the verification token is valid and unexpired' do
      let(:sent_at) { 20.minutes.ago }

      it 'updates the email and clears pending verification fields' do
        get app_verify_email_account_settings_path(token: user.email_change_verification_token)

        expect(user.reload.email).to eq('verified@sitelabs.ai')
        expect(user.pending_email).to be_nil
        expect(user.email_change_verification_token).to be_nil
        expect(user.email_change_verification_sent_at).to be_nil
      end

      it 'redirects to workspaces with a success toast' do
        get app_verify_email_account_settings_path(token: user.email_change_verification_token)

        expect(response).to redirect_to(app_workspaces_path)
        expect(flash[:toast]).to include(
          type: 'success',
          title: I18n.t('toasts.account_settings.email_verified.title'),
          body: I18n.t('toasts.account_settings.email_verified.body')
        )
      end
    end

    context 'when the verification token is expired' do
      let(:sent_at) { 2.hours.ago }

      it 'does not change the email and clears pending verification fields' do
        get app_verify_email_account_settings_path(token: user.email_change_verification_token)

        expect(user.reload.email).to eq('hello@sitelabs.ai')
        expect(user.pending_email).to be_nil
        expect(user.email_change_verification_token).to be_nil
        expect(user.email_change_verification_sent_at).to be_nil
      end

      it 'redirects to account settings with an error toast' do
        get app_verify_email_account_settings_path(token: user.email_change_verification_token)

        expect(response).to redirect_to(app_account_settings_path)
        expect(flash[:toast]).to include(
          type: 'error',
          title: I18n.t('toasts.account_settings.email_verification_expired.title'),
          body: I18n.t('toasts.account_settings.email_verification_expired.body')
        )
      end
    end

    context 'when the token is invalid' do
      let(:sent_at) { 20.minutes.ago }

      it 'redirects to login with an error toast' do
        get app_verify_email_account_settings_path(token: 'invalid-token')

        expect(response).to redirect_to(auth_login_index_path)
        expect(flash[:toast]).to include(
          type: 'error',
          title: I18n.t('toasts.account_settings.email_verification_expired.title'),
          body: I18n.t('toasts.account_settings.email_verification_expired.body')
        )
      end
    end
  end
end
