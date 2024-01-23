# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::Queries', type: :request do
  describe 'GET /app/workspaces/:workspace_id/queries' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }

    before { sign_in(user) }

    context 'when there are no data soures' do
      it 'redirects to create one' do
        get "/app/workspaces/#{workspace.id}/queries"
        expect(response).to redirect_to(new_app_workspace_data_source_path(workspace))
      end
    end

    context 'when there are data sources' do
      context 'and there are no queries' do
        let!(:data_source) { create(:data_source, workspace:) }

        it 'returns an empty state' do
          get "/app/workspaces/#{workspace.id}/queries"
          expect(response.body).to include('Any queries you&apos;ve saved will be available here')
        end
      end

      context 'and there are queries' do
        let!(:data_source) { create(:data_source, workspace:) }

        let!(:query_1) { create(:query, saved: true, name: 'Foo', data_source:) }
        let!(:query_2) { create(:query, saved: true, name: 'Bar', data_source:) }
        let!(:query_3) { create(:query, saved: true, name: 'Baz', data_source:) }
        let!(:query_4) { create(:query, saved: true, name: 'food', data_source:) }
        let!(:query_5) { create(:query, saved: true, name: 'barry', data_source:) }
        let!(:query_6) { create(:query, saved: false, name: 'should not show', data_source:) }

        it 'renders a list of queries page' do
          get "/app/workspaces/#{workspace.id}/queries"

          expect(response.body).to have_selector('.queries-table .name', text: query_1.name)
          expect(response.body).to have_selector('.queries-table .name', text: query_2.name)
          expect(response.body).to have_selector('.queries-table .name', text: query_3.name)
          expect(response.body).to have_selector('.queries-table .name', text: query_4.name)
          expect(response.body).to have_selector('.queries-table .name', text: query_5.name)

          expect(response.body).not_to have_selector('.queries-table .name', text: query_6.name)
        end

        context 'when a search param is provided' do
          it 'returns the results with the matching names' do
            get "/app/workspaces/#{workspace.id}/queries", params: { search: 'foo' }

            expect(response.body).to have_selector('.queries-table .name', text: query_1.name)
            expect(response.body).to have_selector('.queries-table .name', text: query_4.name)

            expect(response.body).not_to have_selector('.queries-table .name', text: query_2.name)
            expect(response.body).not_to have_selector('.queries-table .name', text: query_3.name)
            expect(response.body).not_to have_selector('.queries-table .name', text: query_5.name)
            expect(response.body).not_to have_selector('.queries-table .name', text: query_6.name)
          end
        end
      end
    end
  end
end
