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

      it 'renders account settings tabs' do
        get '/app/account-settings'

        expect(response.body).to include('General')
        expect(response.body).to include('Notifications')
        expect(response.body).to include('Delete Account')
      end

      it 'hides the general form when another tab is selected' do
        get '/app/account-settings', params: { tab: 'notifications' }

        expect(response.body).not_to include('Use the settings below to update your personal account details.')
      end

      it 'renders account deletion guidance when delete account tab is selected' do
        get '/app/account-settings', params: { tab: 'delete_account' }

        expect(response.body).to include('You can delete your account at any time:')
        expect(response.body).to include('Account deletion workspace options')
      end
    end
  end

  describe 'PATCH /app/account-settings' do
    let(:user) { create(:user, first_name: 'Chris', last_name: 'Pattison', email: 'hello@sitelabs.ai') }

    before { sign_in(user) }

    context 'when only name fields are changed' do
      let(:params) { { first_name: 'Christopher', last_name: 'Pattison', email: user.email, preferred_locale: 'en' } }

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
      let(:params) do
        { first_name: 'Christopher', last_name: 'Pattison', email: 'new@sitelabs.ai', preferred_locale: 'en' }
      end

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
          body: I18n.t(
            'toasts.account_settings.email_verification_pending.body',
            email_current: 'hello@sitelabs.ai',
            email_new: 'new@sitelabs.ai'
          )
        )
        expect(flash[:toast][:body_html]).to include('<strong>hello@sitelabs.ai</strong>')
        expect(flash[:toast][:body_html]).to include('<strong>new@sitelabs.ai</strong>')
      end
    end

    context 'when requested email is already in use' do
      let!(:existing_user) { create(:user, email: 'existing@sitelabs.ai') }
      let(:params) do
        { first_name: 'Chris', last_name: 'Pattison', email: existing_user.email, preferred_locale: 'en' }
      end

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

    context 'when update fails unexpectedly' do
      let(:params) { { first_name: 'Christopher', last_name: 'Pattison', email: user.email, preferred_locale: 'en' } }

      before do
        allow_any_instance_of(User).to receive(:update!).and_raise(StandardError, 'boom')
      end

      it 'sets the generic error toast' do
        patch '/app/account-settings', params: params

        expect(flash[:toast]).to include(
          type: 'error',
          title: I18n.t('toasts.generic_error.title'),
          body: I18n.t('toasts.generic_error.body')
        )
      end
    end
  end

  describe 'PATCH /app/account-settings locale selection' do
    let(:user) { create(:user, preferred_locale: 'en') }

    before { sign_in(user) }

    it 'persists a preferred locale update' do
      patch '/app/account-settings', params: {
        first_name: user.first_name,
        last_name: user.last_name,
        email: user.email,
        preferred_locale: 'es'
      }

      expect(user.reload.preferred_locale).to eq('es')
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
        expect(user.email_change_verification_token).to eq('verify-token')
        expect(user.email_change_verification_sent_at).to be_present
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

      it 'accepts token casing variations' do
        user.update!(email_change_verification_token: 'abc123token')

        get app_verify_email_account_settings_path(token: 'ABC123TOKEN')

        expect(response).to redirect_to(app_workspaces_path)
      end

      it 'is idempotent for repeated clicks while token is still valid' do
        get app_verify_email_account_settings_path(token: user.email_change_verification_token)
        get app_verify_email_account_settings_path(token: user.email_change_verification_token)

        expect(response).to redirect_to(app_workspaces_path)
        expect(flash[:toast]).to include(
          type: 'success',
          title: I18n.t('toasts.account_settings.email_verified.title'),
          body: I18n.t('toasts.account_settings.email_verified.body')
        )
      end

      it 'remains successful on repeated clicks after verification window passes' do
        get app_verify_email_account_settings_path(token: user.email_change_verification_token)
        user.update!(email_change_verification_sent_at: 2.hours.ago)

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

      it 'redirects to account settings with an error toast when user is signed in' do
        sign_in(user)

        get app_verify_email_account_settings_path(token: 'invalid-token')

        expect(response).to redirect_to(app_account_settings_path)
        expect(flash[:toast]).to include(
          type: 'error',
          title: I18n.t('toasts.account_settings.email_verification_expired.title'),
          body: I18n.t('toasts.account_settings.email_verification_expired.body')
        )
      end
    end
  end

  describe 'DELETE /app/account-settings' do
    let(:user) { create(:user, first_name: 'Chris', last_name: 'Pattison', email: 'owner@sitelabs.ai') }

    context 'when user is not authenticated' do
      it 'redirects to login' do
        delete '/app/account-settings'

        expect(response).to redirect_to(auth_login_index_path)
      end
    end

    context 'when user is authenticated' do
      before { sign_in(user) }

      it 'deletes account when ownership can transfer and action is provided' do
        workspace = create(:workspace, name: 'Bananas Ltd')
        create(:member, user:, workspace:, role: Member::Roles::OWNER)
        eligible_member = create(:member, workspace:, role: Member::Roles::ADMIN)

        delete '/app/account-settings', params: { workspace_actions: { workspace.id.to_s => eligible_member.id.to_s } }

        expect(response).to redirect_to(root_path)
        expect(User.find_by(id: user.id)).to be_nil
        expect(Workspace.find_by(id: workspace.id)).to be_present
        expect(eligible_member.reload.role).to eq(Member::Roles::OWNER)
        expect(flash[:toast]).to include(
          type: 'success',
          title: I18n.t('toasts.account_settings.account_deleted_success.title'),
          body: I18n.t('toasts.account_settings.account_deleted_success.body')
        )
      end

      it 'returns unresolved toast when transfer action is missing' do
        workspace = create(:workspace, name: 'Alphabet Inc')
        create(:member, user:, workspace:, role: Member::Roles::OWNER)
        create(:member, workspace:, role: Member::Roles::ADMIN)

        delete '/app/account-settings', params: { workspace_actions: { workspace.id.to_s => '' } }

        expect(response).to redirect_to(app_account_settings_path(tab: 'delete_account'))
        expect(User.find_by(id: user.id)).to be_present
        expect(flash[:toast]).to include(
          type: 'error',
          title: I18n.t('toasts.account_settings.account_delete_unresolved_workspaces.title'),
          body: I18n.t('toasts.account_settings.account_delete_unresolved_workspaces.body')
        )
      end

      it 'allows deletion without transfer when no accepted team members exist' do
        workspace = create(:workspace, name: 'Solo Workspace')
        create(:member, user:, workspace:, role: Member::Roles::OWNER)
        create(:member, workspace:, role: Member::Roles::USER, status: Member::Status::PENDING)

        delete '/app/account-settings', params: { workspace_actions: {} }

        expect(response).to redirect_to(root_path)
        expect(User.find_by(id: user.id)).to be_nil
        expect(Workspace.find_by(id: workspace.id)).to be_nil
      end
    end
  end
end
