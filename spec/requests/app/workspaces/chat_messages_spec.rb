# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces chat messages', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: user) }

  before do
    sign_in(user)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)
  end

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

    it 'does not expose another workspace member thread messages' do
      teammate = create(:user)
      create(:member, workspace:, user: teammate, role: Member::Roles::ADMIN, status: Member::Status::ACCEPTED)
      teammate_thread = create(:chat_thread, workspace:, created_by: teammate, title: 'Teammate private')
      create(
        :chat_message,
        chat_thread: teammate_thread,
        user: teammate,
        role: ChatMessage::Roles::USER,
        content: 'Private thread'
      )

      get app_workspace_chat_messages_path(workspace), params: { thread_id: teammate_thread.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({ 'thread_id' => nil, 'messages' => [] })
    end
  end

  describe 'POST /app/workspaces/:workspace_id/chat/messages' do
    it 'creates a basic message and assistant reply' do
      expect do
        post app_workspace_chat_messages_path(workspace), params: { content: 'Hello chat' }, as: :json
      end.to change(ChatMessage, :count).by(2)

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

    it 'auto-executes low-risk write actions' do
      expect do
        post app_workspace_chat_messages_path(workspace), params: { content: 'rename workspace to New Name' }, as: :json
      end.to change(ChatActionRequest, :count).by(1)

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('executed')
      expect(workspace.reload.name).to eq('New Name')
      expect(ChatActionRequest.order(:id).last.status).to eq(ChatActionRequest::Statuses::EXECUTED)
    end

    it 'deduplicates repeated low-risk writes with idempotency keys' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'rename workspace to Repeated Name' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { thread_id:, content: 'rename workspace to Repeated Name' },
             as: :json
      end.not_to change(ChatActionRequest, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(workspace.reload.name).to eq('Repeated Name')
    end

    it 'still executes writes when idempotency column is unavailable' do
      column_names_without_idempotency = ChatActionRequest.column_names - ['idempotency_key']
      allow(ChatActionRequest).to receive(:column_names).and_return(column_names_without_idempotency)

      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { content: 'rename workspace to Fallback Name' },
             as: :json
      end.to change(ChatActionRequest, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(workspace.reload.name).to eq('Fallback Name')
    end

    it 'extracts a clean target name for rename questions' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Can you rename my workspace to Bumanarama?' },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('executed')
      expect(workspace.reload.name).to eq('Bumanarama')
    end

    it 'asks for required invite details before proposing an invite action' do
      expect do
        post app_workspace_chat_messages_path(workspace), params: { content: 'invite my team mates' }, as: :json
      end.not_to change(ChatActionRequest, :count)

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('ok')
      expect(payload['messages'].last['role']).to eq('assistant')
      expect(payload['messages'].last['content']).to eq(
        'Sure. Please share their first name, last name, email address, and role (Admin, User, or Read only).'
      )
    end

    it 'asks for a role after invite follow-up provides name and email' do
      post app_workspace_chat_messages_path(workspace), params: { content: 'show my team members' }, as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'Can I invite someone else?' },
           as: :json

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'Their name is Bob Jenkins and their email is hello@sqlbook.com'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('ok')
      expect(response.parsed_body.dig('messages', -1, 'content')).to eq(
        'Sure. What role should I give them (Admin, User, or Read only)?'
      )
      invited_member = workspace.members.joins(:user).find_by(users: { email: 'hello@sqlbook.com' })
      expect(invited_member).not_to be_present
    end

    it 'continues invite flow after a role follow-up in mixed context threads' do
      post app_workspace_chat_messages_path(workspace), params: { content: 'show my team members' }, as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'Can I invite someone else?' },
           as: :json

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'Their name is Bob Jenkins and their email is hello@sqlbook.com'
           },
           as: :json

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'Admin'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('hello@sqlbook.com')
      invited_member = workspace.members.joins(:user).find_by(users: { email: 'hello@sqlbook.com' })
      expect(invited_member).to be_present
      expect(invited_member.role).to eq(Member::Roles::ADMIN)
    end

    it 'asks for a role when first/last name and email are provided in a single follow-up message' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Can I invite someone else?' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: {
             thread_id:,
             content: 'Chris Smith, hello@sqlbook.com'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('ok')
      expect(payload.dig('messages', -1, 'content')).to eq(
        'Sure. What role should I give them (Admin, User, or Read only)?'
      )

      invited_user = User.find_by(email: 'hello@sqlbook.com')
      expect(invited_user).not_to be_present
    end

    it 'uses recent removed-member context for invite-back requests but still requires a role' do
      teammate = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'hello@sqlbook.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'remove user hello@sqlbook.com' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'I confirm' },
           as: :json

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'Thanks could you invite him back actually?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')
      expect(response.parsed_body.dig('messages', -1, 'content')).to eq(
        'Sure. What role should I give them (Admin, User, or Read only)?'
      )

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'User' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('hello@sqlbook.com')
    end

    it 'answers invite role follow-ups from recent structured invite context' do
      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Can I invite someone else?' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'Chris Smith, hello@sqlbook.com' },
           as: :json

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'User' },
           as: :json

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'What role did you add him as?' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('ok')
      expect(response.parsed_body.dig('messages', -1, 'content')).to eq(
        'I invited Chris Smith as User. Their invitation is currently Pending.'
      )
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

    it 'keeps high-risk member removal behind confirmation' do
      teammate = create(:user, first_name: 'Bob', last_name: 'Smith', email: 'bob@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'remove user bob@example.com' },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('requires_confirmation')
      expect(payload.dig('action_request', 'action_type')).to eq('member.remove')
    end

    it 'creates a pending removal action when user names the member instead of email' do
      teammate = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'chris@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'Can we delete the user Chris Smith?' },
           as: :json

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['status']).to eq('requires_confirmation')
      expect(payload.dig('action_request', 'action_type')).to eq('member.remove')
      expect(payload.dig('action_request', 'payload', 'email')).to eq('chris@example.com')
    end

    it 'allows written confirmation for a pending high-risk action' do
      teammate = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'chris@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'remove user chris@example.com' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      expect do
        post app_workspace_chat_messages_path(workspace),
             params: { thread_id:, content: 'I confirm' },
             as: :json
      end.to change { workspace.members.exists?(user: teammate) }.from(true).to(false)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('messages', -1, 'content')).to include('has been removed')
    end

    it 'allows written cancellation for a pending high-risk action' do
      teammate = create(:user, first_name: 'Chris', last_name: 'Smith', email: 'chris@example.com')
      create(
        :member,
        workspace:,
        user: teammate,
        role: Member::Roles::USER,
        status: Member::Status::ACCEPTED
      )

      post app_workspace_chat_messages_path(workspace),
           params: { content: 'remove user chris@example.com' },
           as: :json
      thread_id = response.parsed_body['thread_id']

      post app_workspace_chat_messages_path(workspace),
           params: { thread_id:, content: 'cancel that' },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('canceled')
      expect(workspace.members.exists?(user: teammate)).to be(true)
      expect(response.parsed_body.dig('messages', -1, 'content')).to eq('Okay, I canceled that action.')
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
