# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API v1 workspace/team tools', type: :request do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner:) }

  describe 'authentication' do
    it 'returns unauthorized when no session is present' do
      get "/api/v1/workspaces/#{workspace.id}/members"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['status']).to eq('unauthorized')
    end
  end

  describe 'authorized workspace/team operations' do
    before { sign_in(owner) }

    it 'lists members for the current workspace' do
      get "/api/v1/workspaces/#{workspace.id}/members"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('data', 'members')).to be_an(Array)
    end

    it 'updates workspace name' do
      patch "/api/v1/workspaces/#{workspace.id}",
            params: { name: 'Renamed from API' },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(workspace.reload.name).to eq('Renamed from API')
    end

    it 'invites a member when a role is provided' do
      post "/api/v1/workspaces/#{workspace.id}/members",
           params: {
             first_name: 'Bob',
             last_name: 'Jenkins',
             email: 'hello@sqlbook.com',
             role: Member::Roles::USER
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      invited_member = workspace.members.joins(:user).find_by(users: { email: 'hello@sqlbook.com' })
      expect(invited_member).to be_present
      expect(invited_member.role).to eq(Member::Roles::USER)
    end

    it 'returns validation error when invite role is omitted' do
      post "/api/v1/workspaces/#{workspace.id}/members",
           params: {
             first_name: 'Bob',
             last_name: 'Jenkins',
             email: 'hello@sqlbook.com'
           },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['status']).to eq('validation_error')
    end
  end

  describe 'role enforcement' do
    let(:admin) { create(:user) }

    before do
      create(:member, workspace:, user: admin, role: Member::Roles::ADMIN)
      sign_in(admin)
    end

    it 'blocks workspace deletion for non-owner members' do
      delete "/api/v1/workspaces/#{workspace.id}", as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['status']).to eq('forbidden')
    end
  end
end
