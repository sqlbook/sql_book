# frozen_string_literal: true

require 'rails_helper'
require 'cgi'

RSpec.describe 'App::Workspaces::Queries', type: :request do
  describe 'GET /app/workspaces/:workspace_id/queries' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner:) }
    let(:owner) { user }

    before { sign_in(user) }

    context 'when there are no data soures' do
      it 'redirects to create one' do
        get "/app/workspaces/#{workspace.id}/queries"
        expect(response).to redirect_to(new_app_workspace_data_source_path(workspace))
      end
    end

    context 'when there are no data soures and current user has user role permissions' do
      let(:owner) { create(:user) }

      before { create(:member, workspace:, user:, role: Member::Roles::USER) }

      it 'renders the workspace breadcrumb as a workspace-home link' do
        get "/app/workspaces/#{workspace.id}/queries"

        expect(response.body)
          .to have_selector(".breadcrumbs-link[href='#{app_workspace_path(workspace)}']", text: workspace.name)
      end

      it 'renders the query library empty state' do
        get "/app/workspaces/#{workspace.id}/queries"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(CGI.escapeHTML(I18n.t('app.workspaces.queries.index.empty')))
      end
    end

    context 'when there are no data soures and current user has read-only role permissions' do
      let(:owner) { create(:user) }

      before { create(:member, workspace:, user:, role: Member::Roles::READ_ONLY) }

      it 'renders the workspace breadcrumb as a workspace-home link' do
        get "/app/workspaces/#{workspace.id}/queries"

        expect(response.body)
          .to have_selector(".breadcrumbs-link[href='#{app_workspace_path(workspace)}']", text: workspace.name)
      end

      it 'renders the query library empty state' do
        get "/app/workspaces/#{workspace.id}/queries"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(CGI.escapeHTML(I18n.t('app.workspaces.queries.index.empty')))
      end
    end

    context 'when there are data sources' do
      context 'and there are no queries' do
        let!(:data_source) { create(:data_source, workspace:) }

        it 'renders the workspace breadcrumb as a workspace-home link' do
          get "/app/workspaces/#{workspace.id}/queries"

          expect(response.body)
            .to have_selector(".breadcrumbs-link[href='#{app_workspace_path(workspace)}']", text: workspace.name)
        end

        it 'returns an empty state' do
          get "/app/workspaces/#{workspace.id}/queries"
          expect(response.body).to include(CGI.escapeHTML(I18n.t('app.workspaces.queries.index.empty')))
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

        it 'renders the stored visible columns preference for the current user' do
          user.update!(ui_preferences: { 'query_library' => { 'visible_columns' => %w[name last_run] } })

          get "/app/workspaces/#{workspace.id}/queries"

          expect(response.body).to have_selector('th[data-query-library-column-key="name"]:not([hidden])')
          expect(response.body).to have_selector('th[data-query-library-column-key="last_run"]:not([hidden])')
          expect(response.body)
            .to have_selector('th[data-query-library-column-key="data_source"][hidden]', visible: false)
          expect(response.body)
            .to have_selector('td[data-query-library-column-key="data_source"][hidden]', visible: false)
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

          it 'keeps the library controls and table headers visible when there are no matches' do
            get "/app/workspaces/#{workspace.id}/queries", params: { search: 'no matches here' }

            expect(response.body).to have_selector('h1', text: I18n.t('app.workspaces.queries.index.title'))
            expect(response.body).to have_selector('input[type="search"][value="no matches here"]')
            expect(response.body).to have_selector(
              '.queries-table th',
              text: I18n.t('app.workspaces.queries.index.columns.name')
            )
            expect(response.body).not_to include(CGI.escapeHTML(I18n.t('app.workspaces.queries.index.empty')))
            expect(response.body).not_to have_selector('.queries-table .name')
          end
        end

        context 'when grouped view is selected' do
          let!(:group_1) { create(:query_group, workspace:, name: 'Audience') }
          let!(:group_2) { create(:query_group, workspace:, name: 'Traffic') }

          before do
            create(:query_group_membership, query: query_1, query_group: group_1)
            create(:query_group_membership, query: query_1, query_group: group_2)
            create(:query_group_membership, query: query_2, query_group: group_2)
          end

          it 'renders grouped drawers and repeats queries that belong to multiple groups' do
            get "/app/workspaces/#{workspace.id}/queries", params: { view: 'groups' }

            expect(response.body).to have_selector('.query-group-drawer__title', text: group_1.name)
            expect(response.body).to have_selector('.query-group-drawer__title', text: group_2.name)
            expect(response.body.scan(%r{>\s*#{Regexp.escape(query_1.name)}\s*</a>}m).size).to eq(2)
            expect(response.body.scan(%r{>\s*#{Regexp.escape(query_2.name)}\s*</a>}m).size).to eq(1)
          end

          it 'keeps all groups visible during search and opens the matching groups' do
            get "/app/workspaces/#{workspace.id}/queries", params: { view: 'groups', search: 'bar' }

            expect(response.body).to have_selector('.query-group-drawer__title', text: group_1.name)
            expect(response.body).to have_selector('.query-group-drawer__title', text: group_2.name)
            expect(response.body).to have_selector('details.query-group-drawer[open] .query-group-drawer__title',
                                                   text: group_2.name)
            expect(response.body).not_to have_selector('details.query-group-drawer[open] .query-group-drawer__title',
                                                       text: group_1.name)
          end
        end
      end
    end
  end

  describe 'PATCH /app/workspaces/:workspace_id/queries/visible-columns' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }

    before { sign_in(user) }

    it 'stores the selected visible columns on the current user' do
      patch app_workspace_query_library_visible_columns_path(workspace),
            params: { visible_columns: %w[name last_run] },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('visible_columns' => %w[name last_run])
      expect(user.reload.query_library_visible_columns).to eq(%w[name last_run])
    end

    it 'falls back to the default columns when none are selected' do
      patch app_workspace_query_library_visible_columns_path(workspace),
            params: { visible_columns: [] },
            as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload.query_library_visible_columns).to eq(User::QUERY_LIBRARY_COLUMNS)
    end
  end

  describe 'DELETE /app/workspaces/:workspace_id/queries/groups/:group_id' do
    let(:user) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner: user) }
    let!(:data_source) { create(:data_source, workspace:) }
    let!(:query_1) { create(:query, saved: true, name: 'Foo', data_source:) }
    let!(:query_2) { create(:query, saved: true, name: 'Bar', data_source:) }
    let!(:group) { create(:query_group, workspace:, name: 'Audience') }

    before do
      sign_in(user)
      create(:query_group_membership, query: query_1, query_group: group)
      create(:query_group_membership, query: query_2, query_group: group)
    end

    it 'removes the group from all queries and deletes the group record' do
      delete app_workspace_query_group_path(workspace, group), params: { view: 'groups' }

      expect(response).to redirect_to(app_workspace_queries_path(workspace, view: 'groups'))
      expect(QueryGroup.exists?(group.id)).to eq(false)
      expect(QueryGroupMembership.where(query_group_id: group.id)).to be_empty
      expect(Query.exists?(query_1.id)).to eq(true)
      expect(Query.exists?(query_2.id)).to eq(true)
    end
  end
end
