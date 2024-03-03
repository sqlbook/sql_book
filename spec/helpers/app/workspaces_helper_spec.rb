# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::WorkspacesHelper', type: :helper do
  describe '#current_user_role' do
    let(:owner) { create(:user) }
    let(:admin) { create(:user) }
    let(:read_only) { create(:user) }

    let(:workspace) { create(:workspace_with_owner, owner:) }

    before do
      create(:member, workspace:, user: admin, role: Member::Roles::ADMIN)
      create(:member, workspace:, user: read_only, role: Member::Roles::READ_ONLY)
    end

    it 'returns the correct values' do
      expect(helper.current_user_role(workspace:, current_user: owner)).to eq(Member::Roles::OWNER)
      expect(helper.current_user_role(workspace:, current_user: admin)).to eq(Member::Roles::ADMIN)
      expect(helper.current_user_role(workspace:, current_user: read_only)).to eq(Member::Roles::READ_ONLY)
    end
  end
end
