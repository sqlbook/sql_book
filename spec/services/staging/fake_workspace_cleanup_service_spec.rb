# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Staging::FakeWorkspaceCleanupService do
  describe '#call' do
    let!(:real_user) { create(:user, email: 'chris.pattison@protonmail.com') }
    let!(:real_workspace) { create(:workspace_with_owner, owner: real_user, name: 'Orange Inc') }

    before do
      Staging::FakeWorkspaceSeedService.new(count: 3).call
    end

    it 'removes only the seeded fake workspaces and fake users' do
      result = described_class.new.call

      expect(result.deleted_workspaces.count).to eq(3)
      expect(Workspace.where("name LIKE 'Seed Workspace %'")).to be_empty
      expect(User.where("email LIKE '%@seed.sqlbook.test'")).to be_empty

      expect(real_workspace.reload).to be_present
      expect(real_user.reload.email).to eq('chris.pattison@protonmail.com')
    end
  end
end
