# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::Members', type: :request do
  describe 'POST /app/workspaces/:workspace_id/members' do
    let(:user) { create(:user) }
    let!(:workspace) { create(:workspace_with_owner, owner: user) }

    let(:params) do
      {
        first_name: 'Bob',
        last_name: 'Dylan',
        email: 'bobdylan@gmail.com',
        role: Member::Roles::READ_ONLY
      }
    end

    before { sign_in(user) }

    it 'creates the user' do
      expect { post "/app/workspaces/#{workspace.id}/members", params: }
        .to change { User.exists?(email: params[:email]) }.from(false).to(true)
    end

    it 'creates the member' do
      expect { post "/app/workspaces/#{workspace.id}/members", params: }.to change { Member.count }.by(1)
    end

    it 'redirects to the workspace settings' do
      post("/app/workspaces/#{workspace.id}/members", params:)
      expect(response).to redirect_to(app_workspace_path(workspace, tab: 'team'))
    end

    context 'when trying to create someone as an owner' do
      let(:params) do
        {
          first_name: 'Bob',
          last_name: 'Dylan',
          email: 'bobdylan@gmail.com',
          role: Member::Roles::OWNER
        }
      end

      it 'does not creat the user' do
        expect { post "/app/workspaces/#{workspace.id}/members", params: }
          .not_to change { User.exists?(email: params[:email]) }
      end

      it 'does not creat the member' do
        expect { post "/app/workspaces/#{workspace.id}/members", params: }.not_to change { Member.count }
      end

      it 'redirects to the workspace settings' do
        post("/app/workspaces/#{workspace.id}/members", params:)
        expect(response).to redirect_to(app_workspace_path(workspace, tab: 'team'))
      end
    end
  end

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
