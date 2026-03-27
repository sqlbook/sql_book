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
      Chat::QuerySaveNameConflictStateStore.new(
        workspace:,
        actor:,
        chat_thread:
      ).save(
        'sql' => 'SELECT first_name, email FROM public.users',
        'question' => 'List user names and emails',
        'data_source_id' => data_source.id,
        'data_source_name' => data_source.display_name,
        'proposed_name' => 'User names and email addresses',
        'conflicting_query_id' => 99,
        'conflicting_query_name' => 'User names and email addresses'
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
      allow_any_instance_of(Chat::DataSourceSetupStateStore).to receive(:load).and_return({})
      allow_any_instance_of(Chat::QueryClarificationStateStore).to receive(:load).and_return({})
      allow_any_instance_of(Chat::QuerySaveNameConflictStateStore).to receive(:load).and_return({})

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
      allow_any_instance_of(Chat::DataSourceSetupStateStore).to receive(:load).and_return({})
      allow_any_instance_of(Chat::QueryClarificationStateStore).to receive(:load).and_return({})
      allow_any_instance_of(Chat::QuerySaveNameConflictStateStore).to receive(:load).and_return({})

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
  end
end
