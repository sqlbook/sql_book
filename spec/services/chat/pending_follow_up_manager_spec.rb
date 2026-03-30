# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::PendingFollowUpManager, type: :service do
  let(:actor) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: actor) }
  let(:chat_thread) { create(:chat_thread, workspace:, created_by: actor) }
  let(:manager) { described_class.new(workspace:, chat_thread:, actor:) }

  describe '#replace!' do
    it 'creates one active follow-up and supersedes the previous active one' do
      first = manager.replace!(
        kind: 'query_rename_suggestion',
        domain: 'query',
        target_type: 'saved_query',
        target_id: 10,
        payload: { suggested_name: '10 longest standing users' }
      )

      second = manager.replace!(
        kind: 'thread_rename_target',
        domain: 'thread',
        target_type: 'chat_thread',
        target_id: chat_thread.id,
        payload: { suggested_title: '10 longest standing users' }
      )

      expect(ChatPendingFollowUp.active.where(chat_thread:, created_by: actor).count).to eq(1)
      expect(ChatPendingFollowUp.find(first['id']).status_name).to eq('superseded')
      expect(ChatPendingFollowUp.find(second['id']).status_name).to eq('active')
    end
  end

  describe '#resolve_active!' do
    it 'marks the active follow-up resolved' do
      manager.replace!(
        kind: 'query_rename_suggestion',
        domain: 'query',
        payload: { suggested_name: '10 longest standing users' }
      )

      payload = manager.resolve_active!
      record = ChatPendingFollowUp.find(payload['id'])

      expect(record.status_name).to eq('resolved')
      expect(record.resolved_at).to be_present
    end
  end

  describe '#clear_kind!' do
    it 'supersedes only the matching active kind' do
      first = manager.replace!(
        kind: 'datasource_setup',
        domain: 'datasource',
        payload: { name: 'Warehouse DB' }
      )
      manager.resolve_active!
      second = manager.replace!(
        kind: 'query_save_name_conflict',
        domain: 'query',
        payload: { proposed_name: 'User count' }
      )

      manager.clear_kind!('query_save_name_conflict')

      expect(ChatPendingFollowUp.find(first['id']).status_name).to eq('resolved')
      expect(ChatPendingFollowUp.find(second['id']).status_name).to eq('superseded')
    end
  end
end
