# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::Members', type: :request do
  describe 'POST /app/workspaces/:workspace_id/members' do
    let(:user) { create(:user) }
    let!(:workspace) { create(:workspace_with_owner, owner: owner) }
    let(:owner) { user }

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

    it 'sets a success toast' do
      post("/app/workspaces/#{workspace.id}/members", params:)

      expect(flash[:toast]).to include(
        type: 'success',
        title: I18n.t('toasts.workspaces.members.invited.title'),
        body: I18n.t('toasts.workspaces.members.invited.body', name: "#{params[:first_name]} #{params[:last_name]}")
      )
    end

    context 'when owner tries to create someone as an owner' do
      let(:params) do
        {
          first_name: 'Bob',
          last_name: 'Dylan',
          email: 'bobdylan@gmail.com',
          role: Member::Roles::OWNER
        }
      end

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

      it 'sets a success toast payload' do
        post("/app/workspaces/#{workspace.id}/members", params:)

        expect(flash[:toast]).to include(
          type: 'success',
          title: I18n.t('toasts.workspaces.members.invited.title'),
          body: I18n.t('toasts.workspaces.members.invited.body', name: "#{params[:first_name]} #{params[:last_name]}")
        )
      end
    end

    context 'when admin tries to create someone as an owner' do
      let(:owner) { create(:user) }
      let(:params) do
        {
          first_name: 'Bob',
          last_name: 'Dylan',
          email: 'bobdylan@gmail.com',
          role: Member::Roles::OWNER
        }
      end

      before { create(:member, workspace:, user:, role: Member::Roles::ADMIN) }

      it 'does not create the user' do
        expect { post "/app/workspaces/#{workspace.id}/members", params: }
          .not_to change { User.exists?(email: params[:email]) }
      end

      it 'does not create the member' do
        expect { post "/app/workspaces/#{workspace.id}/members", params: }.not_to change { Member.count }
      end

      it 'redirects to the workspace settings' do
        post("/app/workspaces/#{workspace.id}/members", params:)
        expect(response).to redirect_to(app_workspace_path(workspace, tab: 'team'))
      end

      it 'sets an error toast payload' do
        post("/app/workspaces/#{workspace.id}/members", params:)

        expect(flash[:toast]).to include(
          type: 'error',
          title: I18n.t('toasts.workspaces.members.owner_invite_forbidden.title'),
          body: I18n.t('toasts.workspaces.members.owner_invite_forbidden.body')
        )
      end
    end

    context 'when trying to create an existing member' do
      let(:existing_user) { create(:user) }
      let!(:existing_member) { create(:member, workspace:, user: existing_user) }

      let(:params) do
        {
          first_name: 'Bob',
          last_name: 'Dylan',
          email: existing_user.email,
          role: Member::Roles::ADMIN
        }
      end

      it 'does not create the user' do
        expect { post "/app/workspaces/#{workspace.id}/members", params: }
          .not_to change { User.exists?(email: params[:email]) }
      end

      it 'does not create the member' do
        expect { post "/app/workspaces/#{workspace.id}/members", params: }.not_to change { Member.count }
      end

      it 'redirects to the workspace settings' do
        post("/app/workspaces/#{workspace.id}/members", params:)
        expect(response).to redirect_to(app_workspace_path(workspace, tab: 'team'))
      end

      it 'sets an information toast payload' do
        post("/app/workspaces/#{workspace.id}/members", params:)

        expect(flash[:toast]).to include(
          type: 'information',
          title: I18n.t('toasts.workspaces.members.already_member.title'),
          body: I18n.t('toasts.workspaces.members.already_member.body')
        )
      end
    end

    context 'when current user has user role permissions' do
      let(:owner) { create(:user) }

      before { create(:member, workspace:, user:, role: Member::Roles::USER) }

      it 'does not create the member' do
        expect { post "/app/workspaces/#{workspace.id}/members", params: }.not_to change(Member, :count)
      end

      it 'redirects to the team tab' do
        post "/app/workspaces/#{workspace.id}/members", params: params
        expect(response).to redirect_to(app_workspace_path(workspace, tab: 'team'))
      end
    end

    context 'when invite creation fails unexpectedly' do
      before do
        allow_any_instance_of(WorkspaceInvitationService).to receive(:invite!)
          .and_raise(ActiveRecord::RecordInvalid.new(User.new))
      end

      it 'sets an error toast payload' do
        post("/app/workspaces/#{workspace.id}/members", params:)

        expect(flash[:toast]).to include(
          type: 'error',
          title: I18n.t('toasts.workspaces.members.invite_failed.title'),
          body: I18n.t('toasts.workspaces.members.invite_failed.body')
        )
        expect(flash[:toast][:actions]).to be_nil
      end
    end
  end

  describe 'DELETE /app/workspaces/:workspace_id/members/:member_id' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner:) }
    let(:owner) { user }

    let(:admin) { create(:user) }
    let!(:member) { create(:member, workspace:, user: admin, role: Member::Roles::ADMIN) }
    let(:mail_delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

    before do
      sign_in(user)
      allow(WorkspaceMailer).to receive(:workspace_member_removed).and_return(mail_delivery)
    end

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

    it 'sets a success toast payload' do
      delete "/app/workspaces/#{workspace.id}/members/#{member.id}"

      expect(flash[:toast]).to include(
        type: 'success',
        title: I18n.t('toasts.workspaces.members.deleted.title'),
        body: I18n.t('toasts.workspaces.members.deleted.body', name: admin.full_name)
      )
    end

    it 'sends a removed-from-workspace email to the deleted accepted member' do
      delete "/app/workspaces/#{workspace.id}/members/#{member.id}"

      expect(WorkspaceMailer).to have_received(:workspace_member_removed).with(
        user: admin,
        workspace_name: workspace.name
      )
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

    context 'when deleting a pending invitation member' do
      let!(:member) do
        create(
          :member,
          workspace:,
          user: admin,
          role: Member::Roles::ADMIN,
          status: Member::Status::PENDING,
          invitation: 'pending-token'
        )
      end

      it 'does not send a removed-from-workspace email' do
        delete "/app/workspaces/#{workspace.id}/members/#{member.id}"

        expect(WorkspaceMailer).not_to have_received(:workspace_member_removed)
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

    context 'when current user has user role permissions' do
      let(:owner) { create(:user) }

      before do
        create(:member, workspace:, user:, role: Member::Roles::USER)
        sign_in(user)
      end

      it 'does not destroy the member' do
        expect { delete "/app/workspaces/#{workspace.id}/members/#{member.id}" }
          .not_to change { Member.exists?(member.id) }
      end

      it 'redirects to team tab' do
        delete "/app/workspaces/#{workspace.id}/members/#{member.id}"
        expect(response).to redirect_to(app_workspace_path(workspace, tab: 'team'))
      end
    end
  end

  describe 'PATCH /app/workspaces/:workspace_id/members/:member_id' do
    let(:owner) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner:) }
    let(:member_user) { create(:user) }
    let!(:member) { create(:member, workspace:, user: member_user, role: Member::Roles::ADMIN) }

    before { sign_in(owner) }

    it 'updates the member role' do
      expect { patch "/app/workspaces/#{workspace.id}/members/#{member.id}", params: { role: Member::Roles::USER } }
        .to change { member.reload.role }.from(Member::Roles::ADMIN).to(Member::Roles::USER)
    end

    it 'redirects to the workspace settings' do
      patch "/app/workspaces/#{workspace.id}/members/#{member.id}", params: { role: Member::Roles::USER }
      expect(response).to redirect_to(app_workspace_path(workspace, tab: 'team'))
    end

    it 'sets a success toast payload' do
      patch "/app/workspaces/#{workspace.id}/members/#{member.id}", params: { role: Member::Roles::USER }

      expect(flash[:toast]).to include(
        type: 'success',
        title: I18n.t('toasts.workspaces.members.role_updated.title'),
        body: I18n.t('toasts.workspaces.members.role_updated.body', name: member_user.full_name, role: 'User')
      )
    end

    context 'when admin updates a lower role member' do
      let(:owner) { create(:user) }
      let(:admin) { create(:user) }
      let(:member_user) { create(:user) }
      let!(:member) { create(:member, workspace:, user: member_user, role: Member::Roles::USER) }

      before do
        create(:member, workspace:, user: admin, role: Member::Roles::ADMIN)
        sign_in(admin)
      end

      it 'allows changing role to admin' do
        expect { patch "/app/workspaces/#{workspace.id}/members/#{member.id}", params: { role: Member::Roles::ADMIN } }
          .to change { member.reload.role }.from(Member::Roles::USER).to(Member::Roles::ADMIN)
      end
    end

    context 'when admin attempts to promote someone to owner' do
      let(:owner) { create(:user) }
      let(:admin) { create(:user) }
      let(:member_user) { create(:user) }
      let!(:member) { create(:member, workspace:, user: member_user, role: Member::Roles::USER) }

      before do
        create(:member, workspace:, user: admin, role: Member::Roles::ADMIN)
        sign_in(admin)
      end

      it 'does not update the member role' do
        expect { patch "/app/workspaces/#{workspace.id}/members/#{member.id}", params: { role: Member::Roles::OWNER } }
          .not_to change { member.reload.role }
      end

      it 'sets an error toast payload' do
        patch "/app/workspaces/#{workspace.id}/members/#{member.id}", params: { role: Member::Roles::OWNER }

        expect(flash[:toast]).to include(
          type: 'error',
          title: I18n.t('toasts.workspaces.members.role_update_failed.title'),
          body: I18n.t('toasts.workspaces.members.role_update_failed.body')
        )
      end
    end

    context 'when current user has user role permissions' do
      let(:owner) { create(:user) }
      let(:user) { create(:user) }

      before do
        create(:member, workspace:, user:, role: Member::Roles::USER)
        sign_in(user)
      end

      it 'does not update the member role' do
        expect { patch "/app/workspaces/#{workspace.id}/members/#{member.id}", params: { role: Member::Roles::USER } }
          .not_to change { member.reload.role }
      end

      it 'redirects to team tab' do
        patch "/app/workspaces/#{workspace.id}/members/#{member.id}", params: { role: Member::Roles::USER }
        expect(response).to redirect_to(app_workspace_path(workspace, tab: 'team'))
      end
    end
  end

  describe 'POST /app/workspaces/:workspace_id/members/:member_id/resend' do
    let(:owner) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner:) }
    let(:invited_user) { create(:user) }
    let(:member_updated_at) { 11.minutes.ago }
    let!(:member) do
      create(
        :member,
        workspace: workspace,
        user: invited_user,
        invited_by: owner,
        role: Member::Roles::ADMIN,
        status: Member::Status::PENDING,
        invitation: 'old_token',
        created_at: member_updated_at,
        updated_at: member_updated_at
      )
    end

    before { sign_in(owner) }

    it 'rotates the invitation token' do
      expect { post "/app/workspaces/#{workspace.id}/members/#{member.id}/resend" }
        .to change { member.reload.invitation }
    end

    it 'redirects to the workspace settings' do
      post "/app/workspaces/#{workspace.id}/members/#{member.id}/resend"
      expect(response).to redirect_to(app_workspace_path(workspace, tab: 'team'))
    end

    it 'sets a success toast payload' do
      post "/app/workspaces/#{workspace.id}/members/#{member.id}/resend"

      expect(flash[:toast]).to include(
        type: 'success',
        title: I18n.t('toasts.workspaces.members.resent.title'),
        body: I18n.t('toasts.workspaces.members.resent.body', name: invited_user.full_name)
      )
    end

    context 'when resend is attempted within cooldown window' do
      let(:member_updated_at) { Time.current }

      it 'does not rotate the invitation token' do
        expect { post "/app/workspaces/#{workspace.id}/members/#{member.id}/resend" }
          .not_to change { member.reload.invitation }
      end

      it 'sets an information toast payload' do
        post "/app/workspaces/#{workspace.id}/members/#{member.id}/resend"

        expect(flash[:toast]).to include(
          type: 'information',
          title: I18n.t('toasts.workspaces.members.resend_blocked.title'),
          body: I18n.t('toasts.workspaces.members.resend_blocked.body', minutes: 10)
        )
      end
    end

    context 'when current user has user role permissions' do
      let(:owner) { create(:user) }
      let(:user) { create(:user) }

      before do
        create(:member, workspace:, user:, role: Member::Roles::USER)
        sign_in(user)
      end

      it 'does not rotate invitation token' do
        expect { post "/app/workspaces/#{workspace.id}/members/#{member.id}/resend" }
          .not_to change { member.reload.invitation }
      end

      it 'redirects to team tab' do
        post "/app/workspaces/#{workspace.id}/members/#{member.id}/resend"
        expect(response).to redirect_to(app_workspace_path(workspace, tab: 'team'))
      end
    end
  end
end
