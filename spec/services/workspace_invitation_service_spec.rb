# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkspaceInvitationService do
  let(:workspace) { create(:workspace) }

  let(:instance) { described_class.new(workspace:) }

  describe '#invite!' do
    let(:first_name) { 'James' }
    let(:last_name) { 'Hetfield' }
    let(:email) { 'downpickingking@gmail.com' }
    let(:role) { Member::Roles::ADMIN }
    let(:invited_by) { create(:user) }

    before do
      allow(WorkspaceMailer).to receive(:invite).and_call_original
    end

    subject { instance.invite!(invited_by:, first_name:, last_name:, email:, role:) }

    context 'when the user does not exist' do
      it 'creates the user' do
        expect { subject }.to change { User.exists?(email:) }.from(false).to(true)
      end

      it 'creates the member' do
        expect { subject }.to change { workspace.reload.members.size }.by(1)
      end

      it 'sends the invitation email' do
        subject
        expect(WorkspaceMailer).to have_received(:invite).with(member: Member.last)
      end

      it 'sets the invited by user' do
        subject
        expect(workspace.reload.members.last.invited_by_id).to eq(invited_by.id)
      end
    end

    context 'when the user already exists' do
      let!(:user) { create(:user, email:) }

      it 'does not the user' do
        expect { subject }.not_to change { User.exists?(email:) }
      end

      it 'does not change any of the users attributes' do
        expect { subject }.not_to change { user.reload.first_name }
      end

      it 'creates the member' do
        expect { subject }.to change { workspace.reload.members.size }.by(1)
      end

      it 'sends the invitation email' do
        subject
        expect(WorkspaceMailer).to have_received(:invite).with(member: Member.last)
      end

      it 'sets the invited by user' do
        subject
        expect(workspace.reload.members.last.invited_by_id).to eq(invited_by.id)
      end
    end
  end

  describe '#reject!' do
    let(:worksapce) { create(:workspace) }

    before do
      allow(WorkspaceMailer).to receive(:invite_reject).and_call_original
    end

    subject { instance.reject!(member:) }

    context 'when the member has no workspaces' do
      let(:user) { create(:user) }
      let(:invited_by) { create(:user) }
      let!(:member) { create(:member, status: Member::Status::PENDING, user:, invited_by:) }

      it 'destroys the member' do
        expect { subject }.to change { Member.exists?(member.id) }.from(true).to(false)
      end

      it 'sends the rejection email to the inviter' do
        subject
        expect(WorkspaceMailer).to have_received(:invite_reject).with(member:)
      end

      it 'destroys the user' do
        expect { subject }.to change { User.exists?(user.id) }.from(true).to(false)
      end
    end

    context 'when the member has other workspaces' do
      let(:user) { create(:user) }
      let(:invited_by) { create(:user) }
      let!(:member) { create(:member, status: Member::Status::PENDING, user:, invited_by:) }

      before do
        # Add the user to another workspace
        other_workspace = create(:workspace)
        create(:member, user:, workspace: other_workspace)
      end

      it 'destroys the member' do
        expect { subject }.to change { Member.exists?(member.id) }.from(true).to(false)
      end

      it 'sends the rejection email to the inviter' do
        subject
        expect(WorkspaceMailer).to have_received(:invite_reject).with(member:)
      end

      it 'does not destroy the user' do
        expect { subject }.not_to change { User.exists?(user.id) }
      end
    end
  end

  describe '#invite!' do
    let!(:member) { create(:member, status: Member::Status::PENDING) }

    subject { instance.accept!(member:) }

    it 'sets the status to accepted' do
      expect { subject }.to change { member.status }.from(Member::Status::PENDING).to(Member::Status::ACCEPTED)
    end
  end
end
