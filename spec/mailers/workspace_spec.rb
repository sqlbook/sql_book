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

  describe '#workspace_deleted' do
    let(:user) { create(:user) }

    subject do
      described_class.workspace_deleted(
        user:,
        workspace_name: 'Acme Workspace',
        workspace_owner_name: 'Chris Pattison'
      )
    end

    it 'renders the correct headers' do
      expect(subject.subject).to eq 'One of your workspaces has been deleted.'
      expect(subject.to).to eq [user.email]
      expect(subject.from).to eq ['noreply@sqlbook.com']
    end

    it 'includes workspace and owner details' do
      expect(subject.body).to include('Acme Workspace has been deleted by Chris Pattison')
      expect(subject.body).to include('the <b>Acme Workspace</b> workspace no longer exists')
      expect(subject.body).to include('/app/workspaces')
    end
  end

  describe '#workspace_member_removed' do
    let(:user) { create(:user) }

    subject do
      described_class.workspace_member_removed(
        user:,
        workspace_name: 'Acme Workspace'
      )
    end

    it 'renders the correct headers' do
      expect(subject.subject).to eq "You've been removed from a workspace."
      expect(subject.to).to eq [user.email]
      expect(subject.from).to eq ['noreply@sqlbook.com']
    end

    it 'includes the workspace name and app link' do
      expect(subject.body).to include('You have been removed from the Acme Workspace workspace team')
      expect(subject.body).to include('you will no longer have access to the <b>Acme Workspace</b> workspace')
      expect(subject.body).to include('/app/workspaces')
      expect(subject.body).to include('Unsubscribe')
    end
  end
end
