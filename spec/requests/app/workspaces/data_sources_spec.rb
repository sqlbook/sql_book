# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::DataSources', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner:) }
  let(:owner) { user }

  before { sign_in(user) }

  describe 'GET /app/workspaces/:workspace_id/data_sources' do
    context 'when there are no data sources' do
      it 'renders the index page without empty datasource sections' do
        get "/app/workspaces/#{workspace.id}/data_sources"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t('app.workspaces.data_sources.index.title'))
        expect(response.body).not_to include(
          I18n.t('app.workspaces.data_sources.index.sections.external_database.title')
        )
        expect(response.body).not_to include(
          I18n.t('app.workspaces.data_sources.index.sections.first_party_capture.title')
        )
        expect(response.body).not_to include(
          'Third-party data library'
        )
      end
    end

    context 'when there are mixed data sources' do
      let!(:capture_source) { create(:data_source, workspace:, name: 'Storefront Capture') }
      let!(:postgres_source) { create(:data_source, :postgres, workspace:, name: 'Warehouse DB') }

      it 'renders workspace breadcrumbs' do
        get "/app/workspaces/#{workspace.id}/data_sources"

        expect(response.body).to have_selector(".breadcrumbs-link[href='#{app_workspaces_path}']", text: 'Workspaces')
        expect(response.body).to have_selector(".breadcrumbs-link[href='#{app_workspace_path(workspace)}']",
                                               text: workspace.name)
        expect(response.body).to have_selector('.breadcrumbs-current', text: 'Data Sources')
      end

      it 'renders grouped rows for capture and external sources' do
        get "/app/workspaces/#{workspace.id}/data_sources"

        expect(response.body).to include('Warehouse DB')
        expect(response.body).to include('Storefront Capture')
        expect(response.body).to include(I18n.t('app.workspaces.data_sources.index.sections.external_database.title'))
        expect(response.body).to include(I18n.t('app.workspaces.data_sources.index.sections.first_party_capture.title'))
        expect(response.body).not_to include(
          'Third-party data library'
        )
      end
    end

    context 'when current user has user role permissions' do
      let(:owner) { create(:user) }

      before { create(:member, workspace:, user:, role: Member::Roles::USER) }

      it 'redirects to workspace list' do
        get "/app/workspaces/#{workspace.id}/data_sources"

        expect(response).to redirect_to(app_workspaces_path)
      end
    end
  end

  describe 'GET /app/workspaces/:workspace_id/data_sources/new' do
    it 'renders the wizard step one by default' do
      get "/app/workspaces/#{workspace.id}/data_sources/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('app.workspaces.data_sources.new.title'))
      expect(response.body).to include(I18n.t('app.workspaces.data_sources.new.source_types.external_database.title'))
    end

    it 'renders the connection step when requested' do
      get "/app/workspaces/#{workspace.id}/data_sources/new", params: { step: 2 }

      expect(response.body).to include(I18n.t('app.workspaces.data_sources.new.fields.database_type'))
      expect(response.body).to include(I18n.t('app.workspaces.data_sources.new.fields.database_type_placeholder'))
      expect(response.body).to include(I18n.t('app.workspaces.data_sources.new.database_types.postgres'))
      expect(response.body).to have_selector(
        "[data-data-source-wizard-target='connectionBox'][hidden]",
        visible: false
      )
    end
  end

  describe 'POST /app/workspaces/:workspace_id/data_sources/validate_connection' do
    let(:available_tables) do
      [
        {
          schema: 'public',
          tables: [
            { name: 'orders', qualified_name: 'public.orders' }
          ]
        }
      ]
    end
    let(:validation_result) do
      DataSources::ConnectionValidationService::Result.new(
        success?: true,
        available_tables:,
        checked_at: Time.zone.local(2026, 3, 20, 10, 0, 0),
        error_code: nil,
        message: nil
      )
    end
    let(:validation_service) { instance_double(DataSources::ConnectionValidationService, call: validation_result) }

    before do
      allow(DataSources::ConnectionValidationService).to receive(:new).and_return(validation_service)
    end

    it 'validates the connection and advances to step three' do
      post "/app/workspaces/#{workspace.id}/data_sources/validate_connection",
           params: {
             name: 'Warehouse DB',
             database_type: 'postgres',
             host: 'db.example.com',
             port: 5432,
             database_name: 'warehouse',
             username: 'readonly',
             password: 'secret'
           }

      expect(response).to redirect_to(new_app_workspace_data_source_path(workspace, step: 3))
      expect(DataSources::ConnectionValidationService).to have_received(:new)
    end

    it 'requires a database type before validating the connection' do
      post "/app/workspaces/#{workspace.id}/data_sources/validate_connection",
           params: {
             name: 'Warehouse DB',
             database_type: '',
             host: 'db.example.com',
             port: 5432,
             database_name: 'warehouse',
             username: 'readonly',
             password: 'secret'
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t('app.workspaces.data_sources.validation.database_type_required'))
      expect(DataSources::ConnectionValidationService).not_to have_received(:new)
    end

    it 'rejects unsupported database types for now' do
      post "/app/workspaces/#{workspace.id}/data_sources/validate_connection",
           params: {
             name: 'Warehouse DB',
             database_type: 'mysql',
             host: 'db.example.com',
             port: 5432,
             database_name: 'warehouse',
             username: 'readonly',
             password: 'secret'
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t('app.workspaces.data_sources.validation.unsupported_database_type'))
      expect(DataSources::ConnectionValidationService).not_to have_received(:new)
    end

    it 'renders step two errors before calling the connection service when required fields are blank' do
      post "/app/workspaces/#{workspace.id}/data_sources/validate_connection",
           params: {
             name: '',
             database_type: 'postgres',
             host: '',
             database_name: '',
             username: '',
             password: ''
           }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to have_selector('.field-error', text: "Name can't be blank")
      expect(response.body).to have_selector('.field-error', text: "Host can't be blank")
      expect(response.body).to have_selector('.field-error', text: "Database name can't be blank")
      expect(response.body).to have_selector('.field-error', text: "Username can't be blank")
      expect(response.body).to have_selector('.field-error', text: "Connection password can't be blank")
      expect(response.body).not_to have_selector('.flash.alert')
      expect(DataSources::ConnectionValidationService).not_to have_received(:new)
    end
  end

  describe 'POST /app/workspaces/:workspace_id/data_sources' do
    let(:available_tables) do
      [
        {
          schema: 'public',
          tables: [
            { name: 'orders', qualified_name: 'public.orders' },
            { name: 'customers', qualified_name: 'public.customers' }
          ]
        }
      ]
    end
    let(:validation_result) do
      DataSources::ConnectionValidationService::Result.new(
        success?: true,
        available_tables:,
        checked_at: Time.zone.local(2026, 3, 20, 10, 0, 0),
        error_code: nil,
        message: nil
      )
    end
    let(:validation_service) { instance_double(DataSources::ConnectionValidationService, call: validation_result) }

    before do
      allow(DataSources::ConnectionValidationService).to receive(:new).and_return(validation_service)
    end

    it 'still supports the first-party capture creation path' do
      expect do
        post "/app/workspaces/#{workspace.id}/data_sources", params: { url: 'https://sqlbook.com' }
      end.to change(DataSource, :count).by(1)

      expect(DataSource.last.source_type).to eq('first_party_capture')
      expect(response).to redirect_to(app_workspace_data_source_set_up_index_path(workspace, DataSource.last.id))
    end

    it 'creates a postgres data source after a successful validation step' do
      post "/app/workspaces/#{workspace.id}/data_sources/validate_connection",
           params: {
             name: 'Warehouse DB',
             database_type: 'postgres',
             host: 'db.example.com',
             port: 5432,
             database_name: 'warehouse',
             username: 'readonly',
             password: 'secret'
           }

      expect do
        post "/app/workspaces/#{workspace.id}/data_sources", params: { selected_tables: ['public.orders'] }
      end.to change { workspace.data_sources.count }.by(1)

      data_source = workspace.data_sources.order(:id).last
      expect(data_source.source_type).to eq('postgres')
      expect(data_source.name).to eq('Warehouse DB')
      expect(data_source.selected_tables).to eq(['public.orders'])
      expect(response).to redirect_to(app_workspace_data_sources_path(workspace))
    end

    it 'renders step three again when too many tables are selected' do
      post "/app/workspaces/#{workspace.id}/data_sources/validate_connection",
           params: {
             name: 'Warehouse DB',
             database_type: 'postgres',
             host: 'db.example.com',
             port: 5432,
             database_name: 'warehouse',
             username: 'readonly',
             password: 'secret'
           }

      selected_tables = Array.new(DataSource::MAX_SELECTED_TABLES + 1) { |index| "public.table_#{index}" }

      post "/app/workspaces/#{workspace.id}/data_sources", params: { selected_tables: selected_tables }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t('app.workspaces.data_sources.validation.selected_tables_limit',
                                              count: DataSource::MAX_SELECTED_TABLES))
    end

    context 'when current user has user role permissions' do
      let(:owner) { create(:user) }

      before { create(:member, workspace:, user:, role: Member::Roles::USER) }

      it 'does not create a data source' do
        expect do
          post "/app/workspaces/#{workspace.id}/data_sources", params: { url: 'https://sqlbook.com' }
        end.not_to change(DataSource, :count)
      end

      it 'redirects to workspace list' do
        post "/app/workspaces/#{workspace.id}/data_sources", params: { url: 'https://sqlbook.com' }

        expect(response).to redirect_to(app_workspaces_path)
      end
    end
  end

  describe 'GET /app/workspaces/:workspace_id/data_sources/:id' do
    let(:capture_source) { create(:data_source, workspace:) }
    let(:postgres_source) { create(:data_source, :postgres, workspace:) }

    it 'renders the capture source settings page' do
      get "/app/workspaces/#{workspace.id}/data_sources/#{capture_source.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('app.workspaces.data_sources.management.fields.tracking_url'))
    end

    it 'renders the postgres source settings page' do
      get "/app/workspaces/#{workspace.id}/data_sources/#{postgres_source.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('app.workspaces.data_sources.management.connection_title'))
      expect(response.body).to include('db.internal')
    end
  end

  describe 'PUT /app/workspaces/:workspace_id/data_sources/:id' do
    let(:data_source) { create(:data_source, workspace:, verified_at: Time.current) }

    it 'updates capture source urls and resets verification' do
      put "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}", params: { url: 'https://valid-url.com' }

      expect(data_source.reload.url).to eq('https://valid-url.com')
      expect(data_source.verified_at).to eq(nil)
      expect(response).to redirect_to(app_workspace_data_source_path(workspace, data_source))
    end
  end

  describe 'DELETE /app/workspaces/:workspace_id/data_sources/:id' do
    let(:data_source) { create(:data_source, workspace:) }

    before do
      create(:member, workspace:)
      create(:member, workspace:)
      create(:member, workspace:)

      allow(DataSourceMailer).to receive(:destroy).and_call_original
    end

    it 'deletes the data source' do
      expect { delete "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}" }
        .to change { DataSource.exists?(data_source.id) }.from(true).to(false)
    end

    it 'sends a mailer to every member in that workspace' do
      delete "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}"

      expect(DataSourceMailer).to have_received(:destroy).exactly(4).times
    end

    context 'when current user has user role permissions' do
      let(:owner) { create(:user) }

      before do
        create(:member, workspace:, user:, role: Member::Roles::USER)
      end

      it 'does not delete the data source' do
        expect { delete "/app/workspaces/#{workspace.id}/data_sources/#{data_source.id}" }
          .not_to change { DataSource.exists?(data_source.id) }
      end
    end
  end
end
