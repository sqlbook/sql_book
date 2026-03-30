# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChatPendingFollowUp, type: :model do
  describe '.active' do
    it 'returns only active non-superseded follow-ups' do
      active_follow_up = create(:chat_pending_follow_up)
      create(:chat_pending_follow_up, status: ChatPendingFollowUp::Statuses::RESOLVED, resolved_at: Time.current)
      create(:chat_pending_follow_up, superseded_at: Time.current)

      expect(described_class.active).to contain_exactly(active_follow_up)
    end
  end

  describe '#serialized_payload' do
    it 'returns normalized structured payload metadata' do
      follow_up = create(
        :chat_pending_follow_up,
        kind: 'thread_rename_target',
        domain: 'thread',
        target_type: 'chat_thread',
        target_id: 42,
        payload: { suggested_title: '10 longest standing users' }
      )

      expect(follow_up.serialized_payload).to include(
        'id' => follow_up.id,
        'kind' => 'thread_rename_target',
        'domain' => 'thread',
        'target_type' => 'chat_thread',
        'target_id' => 42,
        'status' => 'active',
        'payload' => { 'suggested_title' => '10 longest standing users' }
      )
    end
  end
end
