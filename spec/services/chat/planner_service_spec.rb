# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::PlannerService do
  let(:actor) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: actor) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)
  end

  describe '#call' do
    it 'extracts workspace rename target without trailing question punctuation' do
      plan = described_class.new(message: 'Can you rename my workspace to Bumanarama?', workspace:, actor:).call

      expect(plan.action_type).to eq('workspace.update_name')
      expect(plan.payload).to include('name' => 'Bumanarama')
    end

    it 'asks for a workspace name when rename intent has no target name' do
      plan = described_class.new(message: 'rename workspace', workspace:, actor:).call

      expect(plan.action_type).to be_nil
      expect(plan.assistant_message).to eq('Sure. What should the new workspace name be?')
    end

    it 'asks for an email when invite intent is missing recipient details' do
      plan = described_class.new(message: 'invite my team', workspace:, actor:).call

      expect(plan.action_type).to be_nil
      expect(plan.assistant_message).to eq('Sure. What email should I send the invitation to?')
    end

    it 'keeps resend intent distinct from invite intent' do
      plan = described_class.new(message: 'resend invite to sam@example.com', workspace:, actor:).call

      expect(plan.action_type).to eq('member.resend_invite')
      expect(plan.payload).to include('email' => 'sam@example.com')
    end

    it 'creates an invite action when a valid email is present' do
      plan = described_class.new(message: 'invite sam@example.com as admin', workspace:, actor:).call

      expect(plan.action_type).to eq('member.invite')
      expect(plan.payload).to include('email' => 'sam@example.com', 'role' => Member::Roles::ADMIN)
    end
  end
end
