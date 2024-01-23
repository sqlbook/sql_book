# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::Dashboards', type: :request do
  describe 'GET /app/workspaces/:workspace_id/dashboards' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }

    before { sign_in(user) }

    context 'when there are no data soures' do
      it 'redirects to create one' do
        get "/app/workspaces/#{workspace.id}/dashboards"
        expect(response).to redirect_to(new_app_workspace_data_source_path(workspace))
      end
    end

    context 'when there are data sources' do
      let!(:data_source) { create(:data_source, workspace:) }

      it 'renders the dashboards page' do
        get "/app/workspaces/#{workspace.id}/dashboards"

        expect(response.status).to eq(200)
      end
    end
  end
end
