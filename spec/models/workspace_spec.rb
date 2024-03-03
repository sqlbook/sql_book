# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workspace, type: :model do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner:) }

  let!(:admin) { create(:member, workspace:, role: Member::Roles::ADMIN) }
  let!(:read_only) { create(:member, workspace:, role: Member::Roles::READ_ONLY) }

  describe '#owner' do
    subject { workspace.owner }

    it 'returns the owner' do
      expect(subject).to eq(owner)
    end
  end

  describe '#event_limit' do
    subject { workspace.event_limit }

    it 'returns 15_000 until I actually build it' do
      expect(subject).to eq(15_000)
    end
  end

  describe '#role_for' do
    it 'returns the correct roles' do
      expect(workspace.role_for(user: owner)).to eq(Member::Roles::OWNER)
      expect(workspace.role_for(user: admin.user)).to eq(Member::Roles::ADMIN)
      expect(workspace.role_for(user: read_only.user)).to eq(Member::Roles::READ_ONLY)
    end
  end
end
