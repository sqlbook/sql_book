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

    before do
      allow(WorkspaceMailer).to receive(:invite).and_call_original
    end

    subject { instance.invite!(first_name:, last_name:, email:, role:) }

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
