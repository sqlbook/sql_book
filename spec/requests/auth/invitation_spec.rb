# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth::Invitation', type: :request do
  describe 'GET /auth/invitation/:token' do
    subject { get "/auth/invitation/#{token}" }

    context 'when the token is invalid' do
      let(:token) { 'sdfsdfdsfs' }

      it 'redirects to home with an info toast' do
        subject

        expect(response).to redirect_to(root_path)
        expect(flash[:toast]).to include(
          type: 'information',
          title: I18n.t('toasts.invitation.invalid.title'),
          body: I18n.t('toasts.invitation.invalid.body')
        )
      end
    end

    context 'when the token is valid' do
      let(:workspace) { create(:workspace) }
      let(:invited_by) { create(:user) }
      let(:member) { create(:member, workspace:, invitation: SecureRandom.base36, invited_by:) }
      let(:token) { member.invitation }

      it 'renders the confirmation page' do
        subject
        expect(response.status).to eq(200)
        expect(response.body).to include(
          "#{invited_by.full_name} has invited you to join the #{workspace.name} workspace"
        )
      end

      it 'renders terms acceptance content' do
        subject

        expect(response.body).to include('I have read and accept the')
        expect(response.body).to include('Terms of Use')
        expect(response.body).to include('Privacy Policy')
      end
    end
  end

  describe 'POST /auth/invitation/:token/accept' do
    let(:workspace) { create(:workspace) }
    let(:member) { create(:member, workspace:, invitation: SecureRandom.base36) }
    let(:token) { member.invitation }
    let(:workspace_invitation_service) { instance_double(WorkspaceInvitationService, accept!: nil) }

    subject { post "/auth/invitation/#{token}/accept", params: params }

    before do
      allow(WorkspaceInvitationService).to receive(:new).and_return(workspace_invitation_service)
    end

    context 'when terms are accepted' do
      let(:params) { { accept_terms: '1' } }

      it 'sets a session cookie' do
        subject
        expect(session[:current_user_id]).to eq(member.user.id)
      end

      it 'accepts the invite' do
        subject
        expect(workspace_invitation_service).to have_received(:accept!)
      end

      it 'redirects to the workspace' do
        subject
        expect(response).to redirect_to(app_workspace_path(member.workspace))
      end

      it 'persists terms acceptance metadata' do
        member.user.update!(terms_accepted_at: 2.days.ago, terms_version: '2025-01-01')

        subject

        expect(member.user.reload.terms_accepted_at).to be_present
        expect(member.user.reload.terms_version).to eq(User::CURRENT_TERMS_VERSION)
      end
    end

    context 'when terms are not accepted' do
      let(:params) { { accept_terms: '0' } }

      it 'does not accept the invite' do
        subject
        expect(workspace_invitation_service).not_to have_received(:accept!)
      end

      it 'redirects back to invitation page' do
        subject
        expect(response).to redirect_to(auth_invitation_path(token))
      end

      it 'sets an alert flash' do
        subject
        expect(flash[:alert]).to eq(I18n.t('auth.must_accept_terms'))
      end
    end

    context 'when the token is invalid' do
      let(:token) { 'invalid-token' }
      let(:params) { { accept_terms: '1' } }

      it 'redirects to the home page' do
        subject
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST /auth/invitation/:token/reject' do
    let(:workspace) { create(:workspace) }
    let(:member) { create(:member, workspace:, invitation: SecureRandom.base36) }
    let(:token) { member.invitation }
    let(:workspace_invitation_service) { instance_double(WorkspaceInvitationService, reject!: nil) }

    subject { post "/auth/invitation/#{token}/reject" }

    before do
      allow(WorkspaceInvitationService).to receive(:new).and_return(workspace_invitation_service)
    end

    it 'redirects to the home page' do
      subject
      expect(response).to redirect_to(root_path)
    end

    it 'reject the invite' do
      subject
      expect(workspace_invitation_service).to have_received(:reject!)
    end

    context 'when the token is invalid' do
      let(:token) { 'invalid-token' }

      it 'redirects to the home page' do
        subject
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
