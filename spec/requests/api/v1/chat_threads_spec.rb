# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API v1 chat threads', type: :request do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner:) }

  describe 'authentication' do
    it 'returns unauthorized when no session is present' do
      patch "/api/v1/workspaces/#{workspace.id}/chat-threads/1", params: { title: 'New title' }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['status']).to eq('unauthorized')
    end
  end

  describe 'PATCH /api/v1/workspaces/:workspace_id/chat-threads/:id' do
    before { sign_in(owner) }

    it 'renames the current user thread' do
      thread = create(:chat_thread, workspace:, created_by: owner, title: 'Old title')
      create(:chat_message, chat_thread: thread, user: owner, content: 'Hello')

      patch "/api/v1/workspaces/#{workspace.id}/chat-threads/#{thread.id}",
            params: { title: 'New title' },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('data', 'thread', 'title')).to eq('New title')
      expect(thread.reload.title).to eq('New title')
    end

    it 'returns validation_error when title is blank' do
      thread = create(:chat_thread, workspace:, created_by: owner, title: 'Old title')
      create(:chat_message, chat_thread: thread, user: owner, content: 'Hello')

      patch "/api/v1/workspaces/#{workspace.id}/chat-threads/#{thread.id}",
            params: { title: '   ' },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['status']).to eq('validation_error')
      expect(response.parsed_body['error_code']).to eq('title_required')
    end

    it 'forbids renaming another member thread' do
      teammate = create(:user)
      create(:member, workspace:, user: teammate, role: Member::Roles::USER, status: Member::Status::ACCEPTED)
      thread = create(:chat_thread, workspace:, created_by: teammate, title: 'Teammate thread')
      create(:chat_message, chat_thread: thread, user: teammate, content: 'Hello')

      patch "/api/v1/workspaces/#{workspace.id}/chat-threads/#{thread.id}",
            params: { title: 'Nope' },
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['status']).to eq('forbidden')
      expect(thread.reload.title).to eq('Teammate thread')
    end
  end
end
