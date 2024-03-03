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
      let(:member) { create(:member, invitation: SecureRandom.base36) }
      let(:token) { member.invitation }

      it 'redirects to the workspace page' do
        subject
        expect(response).to redirect_to(app_workspace_path(member.workspace))
      end

      it 'sets a session cookie' do
        subject
        expect(session[:current_user_id]).to eq(member.user.id)
      end
    end
  end
end
