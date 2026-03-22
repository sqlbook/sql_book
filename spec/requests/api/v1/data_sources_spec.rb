# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API v1 data sources', type: :request do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner:) }
  let(:postgres_source) do
    create(
      :data_source,
      workspace:,
      name: 'Sales DB',
      source_type: :postgres,
      host: 'db.example.com',
      port: 5432,
      database_name: 'sales',
      username: 'sqlbook',
      connection_password: 'secret',
      selected_tables: ['public.orders'],
      status: :active
    )
  end
  let(:capture_source) do
    create(
      :data_source,
      workspace:,
      name: 'Capture',
      source_type: :first_party_capture,
      url: 'https://capture.sqlbook.com',
      status: :active
    )
  end

  describe 'authentication' do
    it 'returns unauthorized when no session is present' do
      get "/api/v1/workspaces/#{workspace.id}/data-sources"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body['status']).to eq('unauthorized')
    end
  end

  describe 'authorized operations' do
    before do
      sign_in(owner)
      postgres_source
      capture_source
      create(:query, data_source: postgres_source)
    end

    it 'lists workspace data sources' do
      get "/api/v1/workspaces/#{workspace.id}/data-sources"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')

      data_sources = response.parsed_body.dig('data', 'data_sources')
      expect(data_sources).to be_an(Array)
      expect(data_sources.map { |item| item['name'] }).to include('Sales DB', 'Capture')

      sales_source_payload = data_sources.find { |item| item['name'] == 'Sales DB' }
      expect(sales_source_payload['source_type']).to eq('postgres')
      expect(sales_source_payload['related_queries_count']).to eq(1)
    end

    it 'validates a PostgreSQL connection' do
      available_tables = [
        {
          schema: 'public',
          tables: [
            {
              name: 'orders',
              qualified_name: 'public.orders',
              columns: [
                { name: 'id', data_type: 'bigint' }
              ]
            }
          ]
        }
      ]
      validation_result = DataSources::ConnectionValidationService::Result.new(
        success?: true,
        available_tables:,
        checked_at: Time.current,
        error_code: nil,
        message: nil
      )
      validation_service = instance_double(DataSources::ConnectionValidationService, call: validation_result)

      allow(DataSources::ConnectionValidationService).to receive(:new).and_return(validation_service)

      post "/api/v1/workspaces/#{workspace.id}/data-sources/validate-connection",
           params: {
             host: 'db.example.com',
             port: 5432,
             database_name: 'sales',
             username: 'sqlbook',
             password: 'secret',
             ssl_mode: 'prefer'
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')
      expect(response.parsed_body.dig('data', 'checked_at')).to be_present
      expect(response.parsed_body.dig('data', 'available_tables')).to be_present
    end

    it 'creates a PostgreSQL data source' do
      available_tables = [
        {
          schema: 'public',
          tables: [
            {
              name: 'orders',
              qualified_name: 'public.orders',
              columns: [
                { name: 'id', data_type: 'bigint' }
              ]
            }
          ]
        }
      ]
      validation_result = DataSources::ConnectionValidationService::Result.new(
        success?: true,
        available_tables:,
        checked_at: Time.current,
        error_code: nil,
        message: nil
      )
      validation_service = instance_double(DataSources::ConnectionValidationService, call: validation_result)

      allow(DataSources::ConnectionValidationService).to receive(:new).and_return(validation_service)

      post "/api/v1/workspaces/#{workspace.id}/data-sources",
           params: {
             name: 'Ecomm Warehouse',
             host: 'db.example.com',
             port: 5432,
             database_name: 'sales',
             username: 'sqlbook',
             password: 'secret',
             ssl_mode: 'prefer',
             selected_tables: ['public.orders']
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('executed')

      created_source = workspace.data_sources.find_by(name: 'Ecomm Warehouse')
      expect(created_source).to be_present
      expect(created_source.source_type).to eq('postgres')
      expect(created_source.selected_tables).to eq(['public.orders'])
      expect(response.parsed_body.dig('data', 'data_source', 'name')).to eq('Ecomm Warehouse')
      expect(response.parsed_body.dig('data', 'data_source', 'selected_tables')).to eq(['public.orders'])
    end
  end

  describe 'role enforcement' do
    context 'when the current member has user role permissions' do
      let(:member_user) { create(:user) }

      before do
        create(:member, workspace:, user: member_user, role: Member::Roles::USER)
        sign_in(member_user)
        postgres_source
      end

      it 'allows datasource listing' do
        get "/api/v1/workspaces/#{workspace.id}/data-sources"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['status']).to eq('executed')
        expect(response.parsed_body.dig('data', 'data_sources').map { |item| item['name'] }).to include('Sales DB')
      end

      it 'blocks datasource creation for non-admin members' do
        post "/api/v1/workspaces/#{workspace.id}/data-sources",
             params: {
               name: 'Ecomm Warehouse',
               host: 'db.example.com',
               database_name: 'sales',
               username: 'sqlbook',
               password: 'secret',
               selected_tables: ['public.orders']
             },
             as: :json

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['status']).to eq('forbidden')
      end
    end

    context 'when the current member is read-only' do
      let(:read_only_user) { create(:user) }

      before do
        create(:member, workspace:, user: read_only_user, role: Member::Roles::READ_ONLY)
        sign_in(read_only_user)
      end

      it 'blocks datasource listing' do
        get "/api/v1/workspaces/#{workspace.id}/data-sources"

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['status']).to eq('forbidden')
      end
    end
  end
end
