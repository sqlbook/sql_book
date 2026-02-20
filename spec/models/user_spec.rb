# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { create(:user, first_name: 'John', last_name: 'Densmore') }

  describe '#full_name' do
    it 'returns the full name' do
      expect(user.full_name).to eq('John Densmore')
    end
  end

  describe '#member_of?' do
    let(:workspace) { create(:workspace) }

    subject { user.member_of?(workspace:) }

    context 'when the user is not a member of the workspace' do
      it 'returns false' do
        expect(subject).to eq(false)
      end
    end

    context 'when the user is a member of the workspace' do
      before { create(:member, workspace:, user:) }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when the user only has a pending invitation to the workspace' do
      before { create(:member, workspace:, user:, status: Member::Status::PENDING) }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe 'workspace cleanup on user deletion' do
    context 'when the deleted user was the final member of a workspace' do
      let(:user) { create(:user) }
      let!(:workspace) { create(:workspace_with_owner, owner: user) }
      let!(:data_source) { create(:data_source, workspace:) }

      it 'deletes the now-empty workspace' do
        expect { user.destroy! }.to change { Workspace.exists?(workspace.id) }.from(true).to(false)
      end

      it 'deletes workspace-related data through workspace cleanup' do
        expect { user.destroy! }.to change { DataSource.exists?(data_source.id) }.from(true).to(false)
      end
    end

    context 'when the deleted user was the only owner and non-owner members remain' do
      let(:user) { create(:user) }
      let!(:workspace) { create(:workspace_with_owner, owner: user) }
      let!(:teammate) { create(:user) }
      let!(:teammate_member) { create(:member, workspace:, user: teammate, role: Member::Roles::ADMIN) }
      let(:mail_delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

      before do
        allow(WorkspaceMailer).to receive(:workspace_deleted).and_return(mail_delivery)
      end

      it 'deletes the workspace to prevent ownerless workspaces' do
        expect { user.destroy! }.to change { Workspace.exists?(workspace.id) }.from(true).to(false)
      end

      it 'notifies remaining workspace users about workspace deletion' do
        user.destroy!

        expect(WorkspaceMailer).to have_received(:workspace_deleted).with(
          user: teammate,
          workspace_name: workspace.name,
          workspace_owner_name: user.full_name
        )
      end
    end

    context 'when another accepted owner remains in the workspace' do
      let(:user) { create(:user) }
      let!(:workspace) { create(:workspace_with_owner, owner: user) }
      let!(:co_owner) { create(:user) }
      let!(:co_owner_member) { create(:member, workspace:, user: co_owner, role: Member::Roles::OWNER) }
      let(:mail_delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

      before do
        allow(WorkspaceMailer).to receive(:workspace_deleted).and_return(mail_delivery)
      end

      it 'does not delete the workspace' do
        expect { user.destroy! }.not_to change { Workspace.exists?(workspace.id) }.from(true)
      end

      it 'does not send workspace deleted notifications' do
        user.destroy!

        expect(WorkspaceMailer).not_to have_received(:workspace_deleted)
      end
    end
  end
end
