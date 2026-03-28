# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkspaceCapabilityResolver do
  let(:actor) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner: actor) }

  describe '#role' do
    it 'prefers accepted memberships when multiple records exist for the same user' do
      create(
        :member,
        workspace:,
        user: actor,
        role: Member::Roles::READ_ONLY,
        status: Member::Status::PENDING
      )

      resolver = described_class.new(workspace:, actor:)

      expect(resolver.role).to eq(Member::Roles::OWNER)
      expect(resolver.can_manage_workspace_members?).to be(true)
    end

    it 'selects the highest-privilege accepted role when duplicate accepted memberships exist' do
      create(
        :member,
        workspace:,
        user: actor,
        role: Member::Roles::READ_ONLY,
        status: Member::Status::ACCEPTED
      )

      resolver = described_class.new(workspace:, actor:)

      expect(resolver.role).to eq(Member::Roles::OWNER)
      expect(resolver.can_manage_workspace_members?).to be(true)
    end
  end
end
