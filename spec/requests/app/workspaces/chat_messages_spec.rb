# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces chat messages', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: user) }

  before { sign_in(user) }

  describe 'GET /app/workspaces/:workspace_id/chat/messages' do
    it 'returns the active thread messages' do
      thread = ChatThread.active_for(workspace:, user:)
      message = create(
        :chat_message,
        chat_thread: thread,
        user:,
        role: ChatMessage::Roles::USER,
        content: 'Hello'
      )

      get app_workspace_chat_messages_path(workspace), params: { thread_id: thread.id }

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['thread_id']).to eq(thread.id)
      expect(payload['messages'].map { |row| row['id'] }).to include(message.id)
    end
  end

  describe 'POST /app/workspaces/:workspace_id/chat/messages' do
    it 'creates a basic message and assistant reply' do
      expect do
        post app_workspace_chat_messages_path(workspace), params: { content: 'Hello chat' }, as: :json
      end.to change(ChatMessage, :count).by(3)

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('ok')
    end

    it 'returns member list details instead of count-only output' do
      teammate_user = create(:user, first_name: 'Tess', last_name: 'Member', email: 'tess@example.com')
      create(
        :member,
        workspace:,
        user: teammate_user,
        role: Member::Roles::ADMIN,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace), params: { content: 'show my team members' }, as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('executed')
      assistant_message = payload['messages'].last
      expect(assistant_message['role']).to eq('assistant')
      expect(assistant_message['content']).to include('tess@example.com')
      expect(assistant_message['content']).to include('Admin')
    end

    it 'keeps member detail follow-ups in member.list flow' do
      teammate_user = create(:user, first_name: 'Tess', last_name: 'Member', email: 'tess@example.com')
      create(
        :member,
        workspace:,
        user: teammate_user,
        role: Member::Roles::ADMIN,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace), params: { content: 'show my team members' }, as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'sure, but what are their names and details?'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('executed')
      assistant_message = payload['messages'].last
      expect(assistant_message['content']).to include('tess@example.com')
      expect(assistant_message['content']).to include('Role')
      expect(assistant_message['content']).to include('Status')
    end

    it 'creates a new thread with a generated title when thread_id is not provided' do
      expect do
        post app_workspace_chat_messages_path(workspace), params: { content: 'Invite my team mates' }, as: :json
      end.to change(ChatThread, :count).by(1)

      expect(response).to have_http_status(:ok)
      created_thread = ChatThread.order(:id).last
      expect(created_thread.title).to be_present
      expect(created_thread.title).not_to end_with('?')
    end

    it 'creates a confirmation request for write actions' do
      expect do
        post app_workspace_chat_messages_path(workspace), params: { content: 'rename workspace to New Name' }, as: :json
      end.to change(ChatActionRequest, :count).by(1)

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('requires_confirmation')
      expect(payload['action_request']['action_type']).to eq('workspace.update_name')
    end

    it 'extracts a clean target name for rename questions' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Can you rename my workspace to Bumanarama?' },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('requires_confirmation')
      expect(payload['action_request']['action_type']).to eq('workspace.update_name')
      expect(payload['action_request']['payload']['name']).to eq('Bumanarama')
    end

    it 'asks for email before proposing an invite action' do
      expect do
        post app_workspace_chat_messages_path(workspace), params: { content: 'invite my team mates' }, as: :json
      end.not_to change(ChatActionRequest, :count)

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('ok')
      expect(payload['messages'].last['role']).to eq('assistant')
      expect(payload['messages'].last['content']).to eq('Sure. What email should I send the invitation to?')
    end

    it 'asks for workspace name before proposing a rename action' do
      expect do
        post app_workspace_chat_messages_path(workspace), params: { content: 'rename workspace' }, as: :json
      end.not_to change(ChatActionRequest, :count)

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('ok')
      expect(payload['messages'].last['role']).to eq('assistant')
      expect(payload['messages'].last['content']).to eq('Sure. What should the new workspace name be?')
    end

    it 'rejects non-image attachments' do
      post app_workspace_chat_messages_path(workspace),
           params: {
             content: 'Please check this',
             images: [uploaded_text_file]
           },
           as: :multipart

      expect(response).to have_http_status(:unprocessable_entity)
      payload = response.parsed_body
      expect(payload['status']).to eq('validation_error')
    end

    it 'rejects more than 6 images' do
      images = Array.new(7) { uploaded_image_file }
      post app_workspace_chat_messages_path(workspace),
           params: {
             content: 'Too many files',
             images:
           },
           as: :multipart

      expect(response).to have_http_status(:unprocessable_entity)
      payload = response.parsed_body
      expect(payload['status']).to eq('validation_error')
    end

    it 'rejects images larger than 25MB' do
      post app_workspace_chat_messages_path(workspace),
           params: {
             content: 'Too large',
             images: [uploaded_large_image_file]
           },
           as: :multipart

      expect(response).to have_http_status(:unprocessable_entity)
      payload = response.parsed_body
      expect(payload['status']).to eq('validation_error')
      expect(payload['message']).to eq('Images must be 25MB or smaller.')
    end

    it 'returns localized validation copy for Spanish locale' do
      user.update!(preferred_locale: 'es')

      post app_workspace_chat_messages_path(workspace), params: { content: '' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      payload = response.parsed_body
      expect(payload['status']).to eq('validation_error')
      expect(payload['message']).to eq('Se requiere contenido del mensaje o al menos una imagen.')
    end

    it 'returns localized role and status labels for Spanish member list output' do
      user.update!(preferred_locale: 'es')
      teammate = create(:user, first_name: 'Tess', last_name: 'Member', email: 'tess@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::READ_ONLY,
        status: Member::Status::PENDING
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'show current team members' },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('executed')
      assistant_message = payload['messages'].last
      expect(assistant_message['content']).to include('Solo lectura')
      expect(assistant_message['content']).to include('Pendiente')
    end
  end

  describe 'POST /app/workspaces/:workspace_id/chat/actions/:id/confirm' do
    it 'executes a pending rename action after confirmation' do
      thread = ChatThread.active_for(workspace:, user:)
      action_request = create(
        :chat_action_request,
        chat_thread: thread,
        requested_by: user,
        action_type: 'workspace.update_name',
        payload: { 'name' => 'Workspace Renamed Via Chat' },
        status: ChatActionRequest::Statuses::PENDING_CONFIRMATION
      )

      post app_workspace_chat_action_confirm_path(workspace, action_request),
           params: {
             thread_id: thread.id,
             confirmation_token: action_request.confirmation_token
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(workspace.reload.name).to eq('Workspace Renamed Via Chat')
      expect(action_request.reload.status).to eq(ChatActionRequest::Statuses::EXECUTED)
    end

    it 'rejects expired confirmation requests' do
      thread = ChatThread.active_for(workspace:, user:)
      action_request = create(
        :chat_action_request,
        chat_thread: thread,
        requested_by: user,
        status: ChatActionRequest::Statuses::PENDING_CONFIRMATION,
        confirmation_expires_at: 1.minute.ago
      )

      post app_workspace_chat_action_confirm_path(workspace, action_request),
           params: {
             thread_id: thread.id,
             confirmation_token: action_request.confirmation_token
           },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['status']).to eq('validation_error')
      expect(action_request.reload.status).to eq(ChatActionRequest::Statuses::PENDING_CONFIRMATION)
    end

    it 'returns forbidden when payload workspace scope does not match' do
      thread = ChatThread.active_for(workspace:, user:)
      action_request = create(
        :chat_action_request,
        chat_thread: thread,
        requested_by: user,
        action_type: 'workspace.update_name',
        payload: {
          'name' => 'Should Not Persist',
          'workspace_id' => workspace.id + 999,
          'thread_id' => thread.id,
          'message_id' => create(:chat_message, chat_thread: thread, user:).id
        },
        status: ChatActionRequest::Statuses::PENDING_CONFIRMATION
      )

      post app_workspace_chat_action_confirm_path(workspace, action_request),
           params: {
             thread_id: thread.id,
             confirmation_token: action_request.confirmation_token
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('forbidden')
      expect(workspace.reload.name).not_to eq('Should Not Persist')
      expect(action_request.reload.status).to eq(ChatActionRequest::Statuses::FORBIDDEN)
    end
  end

  describe 'POST /app/workspaces/:workspace_id/chat/actions/:id/cancel' do
    it 'cancels a pending action request' do
      thread = ChatThread.active_for(workspace:, user:)
      action_request = create(
        :chat_action_request,
        chat_thread: thread,
        requested_by: user,
        status: ChatActionRequest::Statuses::PENDING_CONFIRMATION
      )

      post app_workspace_chat_action_cancel_path(workspace, action_request),
           params: { thread_id: thread.id },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(action_request.reload.status).to eq(ChatActionRequest::Statuses::CANCELED)
    end
  end

  private

  def uploaded_image_file
    file = Tempfile.new(['chat-image', '.png'])
    file.binmode
    file.write("\x89PNG\r\n\x1A\n")
    file.rewind
    Rack::Test::UploadedFile.new(file.path, 'image/png')
  end

  def uploaded_text_file
    file = Tempfile.new(['chat-text', '.txt'])
    file.write('not an image')
    file.rewind
    Rack::Test::UploadedFile.new(file.path, 'text/plain')
  end

  def uploaded_large_image_file
    file = Tempfile.new(['chat-image-large', '.png'])
    file.binmode
    file.write("\x89PNG\r\n\x1A\n")
    file.truncate(ChatMessage::MAX_IMAGE_SIZE + 1)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, 'image/png')
  end
end
