# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::ContextSnapshotBuilder, type: :service do
  let(:actor) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: actor) }
  let(:chat_thread) { create(:chat_thread, workspace:, created_by: actor) }
  let(:data_source) { create(:data_source, :postgres, workspace:, name: 'Staging App DB') }

  before do
    Rails.cache.clear
  end

  describe '#call' do
    it 'builds query active focus and pending follow-up from a saved-name conflict state' do
      create(
        :chat_pending_follow_up,
        workspace:,
        chat_thread:,
        created_by: actor,
        kind: 'query_save_name_conflict',
        domain: 'query',
        target_type: 'draft_query',
        target_id: nil,
        payload: {
          'sql' => 'SELECT first_name, email FROM public.users',
          'question' => 'List user names and emails',
          'data_source_id' => data_source.id,
          'data_source_name' => data_source.display_name,
          'proposed_name' => 'User names and email addresses',
          'conflicting_query_id' => 99,
          'conflicting_query_name' => 'User names and email addresses'
        }
      )

      snapshot = described_class.new(
        chat_thread:,
        workspace:,
        actor:,
        current_message_text: 'save that'
      ).call

      expect(snapshot.pending_follow_up).to include(
        'domain' => 'query',
        'kind' => 'query_name_conflict',
        'proposed_value' => 'User names and email addresses'
      )
      expect(snapshot.active_focus).to include(
        'domain' => 'query',
        'focus_kind' => 'flow',
        'follow_up_expected' => true
      )
      expect(snapshot.structured_context_sections.map { |section| section[:title] }.first(2)).to eq(
        ['Active focus', 'Pending follow-up']
      )
    end

    it 'builds member active focus from recent member result metadata' do
      create(
        :chat_message,
        chat_thread:,
        role: ChatMessage::Roles::ASSISTANT,
        content: 'Bob Smith has been removed from the workspace.',
        metadata: {
          result_data: {
            removed_member: {
              member_id: 123,
              full_name: 'Bob Smith',
              email: 'bob@example.com',
              role_name: 'User',
              status_name: 'Accepted'
            }
          }
        }
      )

      snapshot = described_class.new(
        chat_thread:,
        workspace:,
        actor:,
        current_message_text: 'What happened to Bob?'
      ).call

      expect(snapshot.active_focus).to include(
        'domain' => 'member',
        'target_type' => 'member',
        'target_name' => 'Bob Smith'
      )
      expect(snapshot.pending_follow_up).to eq({})
    end

    it 'builds workspace active focus from the most recent executed workspace action' do
      source_message = create(:chat_message, chat_thread:, user: actor, content: 'Rename workspace')
      create(
        :chat_action_request,
        chat_thread:,
        chat_message: source_message,
        source_message: source_message,
        requested_by: actor,
        action_type: 'workspace.update_name',
        status: ChatActionRequest::Statuses::EXECUTED,
        result_payload: { 'user_message' => 'Workspace renamed to Orange Inc.' }
      )

      snapshot = described_class.new(
        chat_thread:,
        workspace:,
        actor:,
        current_message_text: 'Thanks'
      ).call

      expect(snapshot.active_focus).to include(
        'domain' => 'workspace',
        'target_type' => 'workspace',
        'target_id' => workspace.id
      )
      expect(snapshot.pending_follow_up).to eq({})
    end

    it 'builds datasource active focus and pending follow-up from setup state' do
      Chat::DataSourceSetupStateStore.new(
        workspace:,
        actor:,
        chat_thread:
      ).save(
        'name' => 'Warehouse DB',
        'source_type' => 'postgres',
        'next_step' => 'selected_tables'
      )

      snapshot = described_class.new(
        chat_thread:,
        workspace:,
        actor:,
        current_message_text: 'Sure'
      ).call

      expect(snapshot.active_focus).to include(
        'domain' => 'datasource',
        'focus_kind' => 'flow',
        'follow_up_expected' => true
      )
      expect(snapshot.pending_follow_up).to include(
        'domain' => 'datasource',
        'kind' => 'datasource_setup_step'
      )
    end

    it 'uses the persisted pending follow-up as the source of truth for rename suggestions' do
      saved_query = create(
        :query,
        data_source: data_source,
        saved: true,
        name: '5 longest standing users',
        query: 'SELECT * FROM public.users ORDER BY created_at ASC LIMIT 10',
        author: actor,
        last_updated_by: actor
      )
      create(
        :chat_pending_follow_up,
        workspace:,
        chat_thread:,
        created_by: actor,
        kind: 'query_rename_suggestion',
        domain: 'query',
        target_type: 'saved_query',
        target_id: saved_query.id,
        payload: {
          'current_name' => '5 longest standing users',
          'suggested_name' => '10 longest standing users',
          'prompt_summary' => 'Consider renaming'
        }
      )

      snapshot = described_class.new(
        chat_thread:,
        workspace:,
        actor:,
        current_message_text: 'yes please'
      ).call

      expect(snapshot.pending_follow_up).to include(
        'kind' => 'query_rename_suggestion',
        'proposed_value' => '10 longest standing users'
      )
      expect(snapshot.active_focus).to include(
        'domain' => 'query',
        'follow_up_expected' => true
      )
    end

    it 'does not infer a pending follow-up from assistant prose alone' do
      create(
        :chat_message,
        chat_thread:,
        role: ChatMessage::Roles::ASSISTANT,
        content: 'This now looks more like a new query than an update.'
      )
      data_source = create(:data_source, :postgres, workspace:, name: 'Warehouse DB')
      create(
        :chat_query_reference,
        chat_thread:,
        data_source:,
        saved_query: create(
          :query,
          data_source:,
          saved: true,
          name: 'Workspace count',
          query: 'SELECT COUNT(*) AS workspace_count FROM public.workspaces',
          author: actor,
          last_updated_by: actor
        ),
        original_question: 'How many workspaces are there?',
        sql: 'SELECT COUNT(*) AS workspace_count FROM public.workspaces',
        current_name: 'Workspace count'
      )

      snapshot = described_class.new(
        chat_thread:,
        workspace:,
        actor:,
        current_message_text: 'okay'
      ).call

      expect(snapshot.pending_follow_up).to eq({})
    end
  end
end
