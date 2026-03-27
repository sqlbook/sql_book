# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces chat query cards', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: user) }
  let(:data_source) { create(:data_source, :postgres, workspace:, name: 'Staging App DB') }
  let(:thread) { create(:chat_thread, workspace:, created_by: user) }

  before { sign_in(user) }

  describe 'POST /app/workspaces/:workspace_id/chat/query-cards/:message_id/save' do
    it 'saves an unsaved chat query and updates the source card state' do
      source_message = create(
        :chat_message,
        chat_thread: thread,
        user: nil,
        role: ChatMessage::Roles::ASSISTANT,
        content: 'Here’s what I found from Staging App DB (1 row(s)):',
        metadata: {
          'query_card' => {
            'state' => 'unsaved',
            'question' => 'How many users do I have?',
            'sql' => 'SELECT COUNT(*) AS user_count FROM public.users;',
            'row_count' => 1,
            'columns' => ['user_count'],
            'rows' => [[3]],
            'suggested_name' => 'User count',
            'data_source' => {
              'id' => data_source.id,
              'name' => data_source.display_name
            }
          }
        }
      )

      expect do
        post app_workspace_chat_query_card_save_path(workspace, source_message),
             params: { thread_id: thread.id },
             as: :json
      end.to change(Query, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('updated_message', 'metadata', 'query_card', 'state')).to eq('saved')
      expect(response.parsed_body.dig('updated_message', 'content_html')).not_to include('[Save Query]')
      expect(response.parsed_body.dig('updated_message', 'content_html')).to include('Open in query library')

      saved_query = Query.order(:id).last
      expect(saved_query.saved).to be(true)
      expect(saved_query.data_source_id).to eq(data_source.id)
      expect(saved_query.name).to eq('User count')
      expect(response.parsed_body.dig('messages', 0, 'content')).to include('User count')
    end
  end
end
