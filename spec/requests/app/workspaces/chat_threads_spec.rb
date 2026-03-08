# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces chat threads', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: user) }

  before { sign_in(user) }

  describe 'GET /app/workspaces/:workspace_id/chat/threads' do
    it 'returns active threads with messages for the workspace only' do
      visible_thread = create(:chat_thread, workspace:, title: 'Invite team')
      create(:chat_message, chat_thread: visible_thread, user:, content: 'Invite')

      hidden_thread = create(:chat_thread, workspace:, title: 'No messages')

      other_workspace = create(:workspace_with_owner)
      other_thread = create(:chat_thread, workspace: other_workspace, title: 'Other')
      create(:chat_message, chat_thread: other_thread, user: other_workspace.members.first.user, content: 'Hi')

      get app_workspace_chat_threads_path(workspace), as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['threads'].map { |thread| thread['id'] }).to include(visible_thread.id)
      expect(payload['threads'].map { |thread| thread['id'] }).not_to include(hidden_thread.id)
      expect(payload['threads'].map { |thread| thread['id'] }).not_to include(other_thread.id)
    end
  end

  describe 'PATCH /app/workspaces/:workspace_id/chat/threads/:id' do
    it 'renames the thread' do
      thread = create(:chat_thread, workspace:, title: 'Old title')
      create(:chat_message, chat_thread: thread, user:, content: 'Hello')

      patch app_workspace_chat_thread_path(workspace, thread), params: { title: 'New title' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(thread.reload.title).to eq('New title')
    end

    it 'returns validation_error when title is blank' do
      thread = create(:chat_thread, workspace:, title: 'Old title')
      create(:chat_message, chat_thread: thread, user:, content: 'Hello')

      patch app_workspace_chat_thread_path(workspace, thread), params: { title: '   ' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['status']).to eq('validation_error')
      expect(response.parsed_body['message']).to eq('Please enter a chat name.')
    end
  end

  describe 'DELETE /app/workspaces/:workspace_id/chat/threads/:id' do
    it 'archives a thread and returns redirect path to another thread' do
      thread = create(:chat_thread, workspace:, title: 'Delete me')
      create(:chat_message, chat_thread: thread, user:, content: 'First')

      keep_thread = create(:chat_thread, workspace:, title: 'Keep me')
      create(:chat_message, chat_thread: keep_thread, user:, content: 'Second')

      delete app_workspace_chat_thread_path(workspace, thread), as: :json

      expect(response).to have_http_status(:ok)
      expect(thread.reload.archived_at).to be_present
      expect(response.parsed_body['redirect_path']).to eq(app_workspace_path(workspace, thread_id: keep_thread.id))
    end
  end
end
