# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkspaceMailer, type: :mailer do
  describe '#invite' do
    let(:invited_by) { create(:user) }
    let(:member) { create(:member, invitation: SecureRandom.base36, invited_by:) }

    subject { described_class.invite(member:) }

    it 'renders the correct headers' do
      expect(subject.subject).to eq "You've been invited to join a workspace on sqlbook."
      expect(subject.to).to eq [member.user.email]
      expect(subject.from).to eq ['noreply@sqlbook.com']
    end

    it 'includes the invitation link' do
      expect(subject.body).to include("/auth/invitation/#{member.invitation}")
    end
  end

  describe '#invite_reject' do
    let(:invited_by) { create(:user) }
    let(:member) { create(:member, invitation: SecureRandom.base36, invited_by:) }

    subject { described_class.invite_reject(member:) }

    it 'renders the correct headers' do
      expect(subject.subject).to eq 'Invitation rejected.'
      expect(subject.to).to eq [member.invited_by.email]
      expect(subject.from).to eq ['noreply@sqlbook.com']
    end

    it 'includes a link to manage the team' do
      expect(subject.body).to include("/app/workspaces/#{member.workspace.id}?tab=team")
    end
  end
end
