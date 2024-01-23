# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::Dashboards', type: :request do
  describe 'GET /app/workspaces/:workspace_id/dashboards' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }

    before { sign_in(user) }

    it 'renders the dashboards page' do
      get "/app/workspaces/#{workspace.id}/dashboards"

      expect(response.status).to eq(200)
    end
  end
end
