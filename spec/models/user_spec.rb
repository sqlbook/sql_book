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

    context 'when the workspace still has other members' do
      let(:user) { create(:user) }
      let!(:workspace) { create(:workspace_with_owner, owner: user) }
      let!(:teammate) { create(:user) }
      let!(:teammate_member) { create(:member, workspace:, user: teammate, role: Member::Roles::ADMIN) }

      it 'does not delete the workspace' do
        expect { user.destroy! }.not_to change { Workspace.exists?(workspace.id) }.from(true)
      end
    end
  end
end
