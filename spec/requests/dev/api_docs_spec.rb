# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dev::ApiDocs', type: :request do
  describe 'GET /dev/api' do
    it 'renders the scalar documentation shell' do
      get '/dev/api'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('api-reference')
      expect(response.body).to include('/dev/api/openapi.json')
      expect(response.body).to include('@scalar/api-reference')
      expect(response.body).to include('Scalar.createApiReference')
    end
  end

  describe 'GET /dev/api/openapi.json' do
    it 'returns a valid openapi document with workspace/team paths' do
      get '/dev/api/openapi.json'

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload['openapi']).to start_with('3.')
      expect(payload.fetch('tags', []).map { |tag| tag['name'] }).to include('Workspace', 'Members')
      expect(payload['x-tagGroups']).to be_present
      expect(payload['x-scalar-environments']).to be_present
      expect(payload.fetch('paths', {}).keys).to include(
        '/api/v1/workspaces/{workspace_id}',
        '/api/v1/workspaces/{workspace_id}/members',
        '/api/v1/workspaces/{workspace_id}/members/resend-invite',
        '/api/v1/workspaces/{workspace_id}/members/{id}/role',
        '/api/v1/workspaces/{workspace_id}/members/{id}'
      )
      expect(payload.dig('paths', '/api/v1/workspaces/{workspace_id}', 'patch', 'x-codeSamples')).to be_present
    end
  end
end
