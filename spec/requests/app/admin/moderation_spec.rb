# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Admin moderation', type: :request do
  let(:super_admin) { create(:user, super_admin: true) }

  before do
    ActionMailer::Base.deliveries.clear
    sign_in(super_admin)
  end

  describe 'PATCH /app/admin/workspaces/:workspace_id/members/:id' do
    let(:workspace) { create(:workspace) }
    let(:owner_user) { create(:user) }
    let(:member_user) { create(:user) }
    let!(:owner_member) { create(:member, workspace:, user: owner_user, role: Member::Roles::OWNER) }
    let!(:member) { create(:member, workspace:, user: member_user, role: Member::Roles::USER) }

    it 'updates a member role without sending emails' do
      expect do
        patch app_admin_workspace_member_path(workspace, member), params: { role: Member::Roles::ADMIN }
      end.not_to change(ActionMailer::Base.deliveries, :count)

      expect(response).to redirect_to(app_admin_workspaces_path(q: nil, workspace_id: workspace.id))
      expect(member.reload.role).to eq(Member::Roles::ADMIN)
    end

    it 'prevents demoting the last owner' do
      patch app_admin_workspace_member_path(workspace, owner_member), params: { role: Member::Roles::ADMIN }

      expect(response).to redirect_to(app_admin_workspaces_path(q: nil, workspace_id: workspace.id))
      expect(owner_member.reload.role).to eq(Member::Roles::OWNER)
      expect(flash[:toast][:type]).to eq('error')
    end
  end

  describe 'DELETE /app/admin/workspaces/:workspace_id/members/:id' do
    let(:workspace) { create(:workspace) }
    let(:owner_user) { create(:user) }
    let(:member_user) { create(:user) }
    let!(:owner_member) { create(:member, workspace:, user: owner_user, role: Member::Roles::OWNER) }
    let!(:member) { create(:member, workspace:, user: member_user, role: Member::Roles::USER) }

    it 'removes a non-owner member without sending emails' do
      expect do
        delete app_admin_workspace_member_path(workspace, member)
      end.to change(Member, :count).by(-1)

      expect(ActionMailer::Base.deliveries.count).to eq(0)

      expect(response).to redirect_to(app_admin_workspaces_path(q: nil, workspace_id: workspace.id))
    end

    it 'prevents removing the last owner' do
      delete app_admin_workspace_member_path(workspace, owner_member)

      expect(response).to redirect_to(app_admin_workspaces_path(q: nil, workspace_id: workspace.id))
      expect(Member.exists?(owner_member.id)).to be(true)
      expect(flash[:toast][:type]).to eq('error')
    end
  end

  describe 'DELETE /app/admin/users/:id' do
    let(:target_user) { create(:user) }

    it 'does not allow super-admin to delete themselves' do
      delete app_admin_user_path(super_admin)

      expect(response).to redirect_to(app_admin_users_path(q: nil, user_id: super_admin.id))
      expect(User.exists?(super_admin.id)).to be(true)
      expect(flash[:toast][:type]).to eq('error')
    end

    it 'deletes a user and transfers owned workspace when selection is provided' do
      workspace = create(:workspace, name: 'Team Blue')
      create(:member, workspace:, user: target_user, role: Member::Roles::OWNER, status: Member::Status::ACCEPTED)

      promoted_user = create(:user, first_name: 'New', last_name: 'Owner')
      promoted_member = create(
        :member,
        workspace:,
        user: promoted_user,
        role: Member::Roles::ADMIN,
        status: Member::Status::ACCEPTED
      )

      expect do
        delete app_admin_user_path(target_user),
               params: { workspace_actions: { workspace.id.to_s => promoted_member.id.to_s } }
      end.to change(User, :count).by(-1)

      expect(response).to redirect_to(app_admin_users_path(q: nil))
      expect(promoted_member.reload.role).to eq(Member::Roles::OWNER)
      expect(ActionMailer::Base.deliveries.count).to eq(0)
    end
  end
end
