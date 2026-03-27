# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::PromptContextFormatter do
  describe '#call' do
    it 'renders structured sections in a stable order before recent conversation' do
      context_snapshot = Chat::ContextSnapshot.new(
        structured_context_sections: [
          { title: 'Active focus', lines: ['domain=query | focus_kind=result'] },
          { title: 'Pending follow-up', lines: ['domain=query | kind=query_name_conflict'] },
          { title: 'Connected data sources', lines: ['Connected data source: Staging App DB | postgres'] }
        ]
      )

      formatted = described_class.new(
        context_snapshot:,
        conversation_messages: [
          { role: 'user', content: 'save that' },
          { role: 'assistant', content: 'I can save it.' }
        ],
        transcript_limit: 8,
        transcript_character_limit: 200
      ).call

      expect(formatted).to eq(
        [
          "Active focus:\ndomain=query | focus_kind=result",
          "Pending follow-up:\ndomain=query | kind=query_name_conflict",
          "Connected data sources:\nConnected data source: Staging App DB | postgres",
          "Recent conversation:\nuser: save that\nassistant: I can save it."
        ].join("\n")
      )
    end

    it 'falls back to legacy structured context lines when the snapshot is not typed' do
      context_snapshot = instance_double(
        Chat::ContextSnapshot,
        structured_context_lines: ['Recent invited member: Bob Smith | bob@example.com']
      )

      formatted = described_class.new(
        context_snapshot:,
        conversation_messages: [],
        transcript_limit: 8,
        transcript_character_limit: 200
      ).call

      expect(formatted).to eq(
        "Recent structured context:\nRecent invited member: Bob Smith | bob@example.com"
      )
    end
  end
end
