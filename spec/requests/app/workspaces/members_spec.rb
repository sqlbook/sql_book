# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::Members', type: :request do
  describe 'DELETE /app/workspaces/:workspace_id/members/:member_id' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }

    let(:admin) { create(:user) }
    let!(:member) { create(:member, workspace:, user: admin, role: Member::Roles::ADMIN) }

    before { sign_in(user) }

    it 'destroys the member record' do
      expect { delete "/app/workspaces/#{workspace.id}/members/#{member.id}" }
        .to change { Member.exists?(member.id) }.from(true).to(false)
    end

    it 'does not destroy the user record' do
      expect { delete "/app/workspaces/#{workspace.id}/members/#{member.id}" }.not_to change { User.exists?(admin.id) }
    end

    it 'redirects to the workspace settings' do
      delete "/app/workspaces/#{workspace.id}/members/#{member.id}"
      expect(response).to redirect_to(app_workspace_path(workspace, tab: 'team'))
    end

    context 'when attempting to delete the owner' do
      it 'does not destroy the owner' do
        expect { delete "/app/workspaces/#{workspace.id}/members/#{user.id}" }
          .not_to change { Member.exists?(workspace.owner.id) }
      end

      it 'redirects to the workspace settings' do
        delete "/app/workspaces/#{workspace.id}/members/#{user.id}"
        expect(response).to redirect_to(app_workspace_path(workspace, tab: 'team'))
      end
    end

    context 'when attempting to delete a member with a lower role' do
      let(:admin) { create(:user) }
      let!(:admin_member) { create(:member, workspace:, user: admin, role: Member::Roles::ADMIN) }

      let(:read_only) { create(:user) }
      let!(:read_only_member) { create(:member, workspace:, user: read_only, role: Member::Roles::READ_ONLY) }

      before { sign_in(read_only) }

      it 'does not destroy the member' do
        expect { delete "/app/workspaces/#{workspace.id}/members/#{admin_member.id}" }
          .not_to change { Member.exists?(workspace.owner.id) }
      end

      it 'redirects to the workspace settings' do
        delete "/app/workspaces/#{workspace.id}/members/#{admin_member.id}"
        expect(response).to redirect_to(app_workspace_path(workspace, tab: 'team'))
      end
    end
  end
end
