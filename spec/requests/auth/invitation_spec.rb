# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth::Invitation', type: :request do
  describe 'GET /auth/invitation/:token' do
    subject { get "/auth/invitation/#{token}" }

    context 'when the token is invalid' do
      let(:token) { 'sdfsdfdsfs' }

      it 'renders the error page' do
        subject

        expect(response.status).to eq(200)
        expect(response.body).to include('Your invitation link is no longer valid')
      end
    end

    context 'when the token is valid' do
      let(:workspace) { create(:workspace) }
      let(:member) { create(:member, workspace:, invitation: SecureRandom.base36) }
      let(:token) { member.invitation }

      it 'renders the confirmation page' do
        subject
        expect(response.status).to eq(200)
        expect(response.body).to include("You have been invited you to join the #{workspace.name} workspace")
      end
    end
  end

  describe 'POST /auth/invitation/:token/accept' do
    let(:workspace) { create(:workspace) }
    let(:member) { create(:member, workspace:, invitation: SecureRandom.base36) }
    let(:token) { member.invitation }
    let(:workspace_invitation_service) { instance_double(WorkspaceInvitationService, accept!: nil) }

    subject { post "/auth/invitation/#{token}/accept" }

    before do
      allow(WorkspaceInvitationService).to receive(:new).and_return(workspace_invitation_service)
    end

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
  end
end
