# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Admin navigation', type: :request do
  let(:super_admin) { create(:user, super_admin: true) }

  before { sign_in(super_admin) }

  describe 'GET /app/admin' do
    it 'renders the dashboard' do
      get app_admin_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Admin Dashboard')
    end
  end

  describe 'GET /app/admin/workspaces' do
    let!(:workspace) { create(:workspace_with_owner, name: 'Quokka Inc') }

    it 'renders the workspace table' do
      get app_admin_workspaces_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Admin Workspaces')
      expect(response.body).to include('Quokka Inc')
    end
  end

  describe 'GET /app/admin/users' do
    let!(:user) { create(:user, first_name: 'Chris', last_name: 'Pattison', email: 'chris@example.com') }

    it 'renders the users table' do
      get app_admin_users_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Admin Users')
      expect(response.body).to include('Chris Pattison')
    end
  end
end
