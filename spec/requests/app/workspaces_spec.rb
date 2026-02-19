# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces', type: :request do
  describe 'GET /app/workspaces' do
    let(:user) { create(:user) }

    before { sign_in(user) }

    context 'when there are no workspaces' do
      it 'redirects to the new page' do
        get '/app/workspaces'
        expect(response).to redirect_to(new_app_workspace_path)
      end
    end

    context 'when there are workspaces' do
      let!(:workspace_1) { create(:workspace_with_owner, name: 'Workspace 1', owner: user) }
      let!(:workspace_2) { create(:workspace_with_owner, name: 'Workspace 1', owner: user) }

      it 'renders a list of workspaces' do
        get '/app/workspaces'

        expect(response.body).to have_selector('.workspace-card h4 a', text: workspace_1.name)
        expect(response.body).to have_selector('.workspace-card h4 a', text: workspace_2.name)
      end

      context 'when the user has a pending invitation' do
        let(:invited_workspace) { create(:workspace, name: 'Invited Workspace') }
        let!(:pending_member) do
          create(
            :member,
            workspace: invited_workspace,
            user: user,
            invited_by: create(:user),
            role: Member::Roles::USER,
            status: Member::Status::PENDING,
            invitation: 'pending-token'
          )
        end

        it 'renders a pending invitation toast with a view invitation action' do
          get '/app/workspaces'

          expect(response.body).to include(I18n.t('toasts.invitation.pending.title'))
          expect(response.body).to include(
            CGI.escapeHTML(I18n.t('toasts.invitation.pending.body', workspace_name: invited_workspace.name))
          )
          expect(response.body).to include('[View invitation]')
          expect(response.body).to include(auth_invitation_path(pending_member.invitation))
          expect(response.body).not_to include(reject_auth_invitation_path(pending_member.invitation))
        end
      end
    end

    context 'when user cannot manage workspace settings' do
      let(:owner) { create(:user) }
      let!(:workspace) { create(:workspace_with_owner, name: 'Locked Workspace', owner:) }

      before { create(:member, workspace:, user:, role: Member::Roles::READ_ONLY) }

      it 'does not render the settings link on the workspace card' do
        get '/app/workspaces'

        expect(response.body).not_to include(%(aria-label="View settings for the #{workspace.name} workspace"))
      end
    end
  end

  describe 'GET /app/workspaces/new' do
    let(:user) { create(:user) }

    before { sign_in(user) }

    it 'renders a form to enter a name' do
      get '/app/workspaces/new'
      expect(response.body).to include('id="name"')
    end

    it 'shows a welcome message' do
      get '/app/workspaces/new'
      expect(response.body).to include('Welcome to sqlbook')
    end

    context 'if the user already has workspaces' do
      before do
        create(:workspace_with_owner, owner: user)
      end

      it 'shows a boring message' do
        get '/app/workspaces/new'
        expect(response.body).to include('Create new workspace')
      end
    end
  end

  describe 'POST /app/workspaces' do
    let(:user) { create(:user) }

    before do
      sign_in(user)
    end

    context 'when no name is provided' do
      it 'redirects back to the new page' do
        post '/app/workspaces'
        expect(response).to redirect_to(new_app_workspace_path)
      end
    end

    context 'when a name is provided' do
      let(:name) { 'My Workspace' }

      context 'and it is their first workspace' do
        it 'redirects them to create a data source' do
          post '/app/workspaces', params: { name: }
          expect(response).to redirect_to(new_app_workspace_data_source_path(Workspace.last))
        end
      end

      context 'and they have existing data sources' do
        before do
          create(:workspace_with_owner, owner: user)
        end

        it 'redirects them to the workspaces page' do
          post '/app/workspaces', params: { name: }
          expect(response).to redirect_to(app_workspaces_path)
        end
      end
    end
  end

  describe 'GET /app/workspaces/:workspace_id' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner:) }
    let(:owner) { user }

    before do
      sign_in(user)
    end

    context 'when the workspace does not exist' do
      it 'renders the 404 page' do
        get "/app/workspace/#{workspace.id}"
        expect(response.status).to eq(404)
      end
    end

    context 'when the workspace exists' do
      it 'renders the show page' do
        get "/app/workspaces/#{workspace.id}"
        expect(response.status).to eq(200)
      end
    end

    context 'when current user is an admin of the workspace' do
      let(:owner) { create(:user) }

      before { create(:member, workspace:, user:, role: Member::Roles::ADMIN) }

      it 'renders the show page' do
        get "/app/workspaces/#{workspace.id}"
        expect(response.status).to eq(200)
      end
    end

    context 'when current user is a user role member of the workspace' do
      let(:owner) { create(:user) }

      before { create(:member, workspace:, user:, role: Member::Roles::USER) }

      it 'redirects to workspace list' do
        get "/app/workspaces/#{workspace.id}"
        expect(response).to redirect_to(app_workspaces_path)
      end

      it 'sets an error toast payload' do
        get "/app/workspaces/#{workspace.id}"
        expect(flash[:toast]).to include(
          type: 'error',
          title: I18n.t('toasts.workspaces.access_forbidden.title'),
          body: I18n.t('toasts.workspaces.access_forbidden.body')
        )
      end
    end

    context 'when current user is read-only in the workspace' do
      let(:owner) { create(:user) }

      before { create(:member, workspace:, user:, role: Member::Roles::READ_ONLY) }

      it 'redirects to workspace list' do
        get "/app/workspaces/#{workspace.id}"
        expect(response).to redirect_to(app_workspaces_path)
      end
    end

    context 'when current user was removed from the workspace' do
      let(:owner) { create(:user) }
      let!(:removed_member) { create(:member, workspace:, user:, role: Member::Roles::USER) }

      before do
        removed_member.destroy
      end

      it 'redirects to workspace list' do
        get "/app/workspaces/#{workspace.id}", params: { tab: 'team' }
        expect(response).to redirect_to(app_workspaces_path)
      end

      it 'sets a workspace unavailable toast payload' do
        get "/app/workspaces/#{workspace.id}", params: { tab: 'team' }
        expect(flash[:toast]).to include(
          type: 'error',
          title: I18n.t('toasts.workspaces.unavailable.title'),
          body: I18n.t('toasts.workspaces.unavailable.body')
        )
      end
    end
  end

  describe 'PATCH /app/workspaces/:workspace_id' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner:) }
    let(:owner) { user }

    before { sign_in(user) }

    it 'updates the workspace' do
      expect { patch "/app/workspaces/#{workspace.id}", params: { name: 'new_name' } }
        .to change { workspace.reload.name }.from(workspace.name).to('new_name')
    end

    it 'redirects to the general tab' do
      patch "/app/workspaces/#{workspace.id}", params: { name: 'new_name' }
      expect(response).to redirect_to(app_workspace_path(workspace, tab: 'general'))
    end

    context 'when current user is an admin of the workspace' do
      let(:owner) { create(:user) }

      before { create(:member, workspace:, user:, role: Member::Roles::ADMIN) }

      it 'updates the workspace' do
        expect { patch "/app/workspaces/#{workspace.id}", params: { name: 'new_name' } }
          .to change { workspace.reload.name }.from(workspace.name).to('new_name')
      end
    end

    context 'when current user is a user role member of the workspace' do
      let(:owner) { create(:user) }

      before { create(:member, workspace:, user:, role: Member::Roles::USER) }

      it 'does not update the workspace' do
        expect { patch "/app/workspaces/#{workspace.id}", params: { name: 'new_name' } }
          .not_to change { workspace.reload.name }
      end

      it 'redirects to workspace list' do
        patch "/app/workspaces/#{workspace.id}", params: { name: 'new_name' }
        expect(response).to redirect_to(app_workspaces_path)
      end
    end
  end

  describe 'DELETE /app/workspaces/:workspace_id' do
    let(:user) { create(:user) }
    let!(:workspace) { create(:workspace_with_owner, owner: user) }

    before { sign_in(user) }

    it 'destroys the workspace' do
      expect { delete "/app/workspaces/#{workspace.id}" }
        .to change { Workspace.exists?(workspace.id) }.from(true).to(false)
    end

    it 'redirects to the workspaces page' do
      delete "/app/workspaces/#{workspace.id}"
      expect(response).to redirect_to(app_workspaces_path)
    end

    it 'sets a success toast payload' do
      delete "/app/workspaces/#{workspace.id}"

      expect(flash[:toast]).to include(
        type: 'success',
        title: I18n.t('toasts.workspaces.deleted.title'),
        body: I18n.t('toasts.workspaces.deleted.body')
      )
    end

    it 'notifies other workspace members' do
      teammate_1 = create(:user)
      teammate_2 = create(:user)
      create(:member, workspace:, user: teammate_1, role: Member::Roles::ADMIN)
      create(:member, workspace:, user: teammate_2, role: Member::Roles::READ_ONLY)

      mail_delivery = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      allow(WorkspaceMailer).to receive(:workspace_deleted).and_return(mail_delivery)

      delete "/app/workspaces/#{workspace.id}"

      expect(WorkspaceMailer).to have_received(:workspace_deleted).with(
        user: teammate_1,
        workspace_name: workspace.name,
        workspace_owner_name: user.full_name
      )
      expect(WorkspaceMailer).to have_received(:workspace_deleted).with(
        user: teammate_2,
        workspace_name: workspace.name,
        workspace_owner_name: user.full_name
      )
      expect(WorkspaceMailer).not_to have_received(:workspace_deleted).with(
        hash_including(user:)
      )
    end

    context 'when current user is not the owner' do
      let(:owner) { create(:user) }
      let(:user) { create(:user) }
      let!(:workspace) { create(:workspace_with_owner, owner:) }

      before do
        create(:member, workspace:, user:, role: Member::Roles::ADMIN)
      end

      it 'does not delete the workspace' do
        expect { delete "/app/workspaces/#{workspace.id}" }
          .not_to change { Workspace.exists?(workspace.id) }
      end

      it 'redirects to workspace settings' do
        delete "/app/workspaces/#{workspace.id}"

        expect(response).to redirect_to(app_workspace_path(workspace, tab: 'general'))
      end

      it 'sets an error toast payload' do
        delete "/app/workspaces/#{workspace.id}"

        expect(flash[:toast]).to include(
          type: 'error',
          title: I18n.t('toasts.workspaces.delete_forbidden.title'),
          body: I18n.t('toasts.workspaces.delete_forbidden.body')
        )
      end
    end
  end
end
