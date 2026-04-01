# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API v1 visualization themes', type: :request do
  let(:owner) { create(:user) }
  let(:workspace) { create(:workspace_with_owner, owner:) }

  before { sign_in(owner) }

  it 'lists the built-in system theme and workspace themes' do
    create(:visualization_theme, workspace:, name: 'Editorial Contrast')

    get "/api/v1/workspaces/#{workspace.id}/visualization-themes"

    expect(response).to have_http_status(:ok)
    names = response.parsed_body.dig('data', 'themes').map { |theme| theme['name'] }
    expect(names).to include('Default Theming', 'Editorial Contrast')
  end

  it 'creates a workspace-owned visualization theme' do
    post "/api/v1/workspaces/#{workspace.id}/visualization-themes",
         params: {
           name: 'Board Room',
           default: true,
           theme_json_dark: { color: ['#111111'], backgroundColor: '#000000' },
           theme_json_light: { color: ['#eeeeee'], backgroundColor: '#ffffff' }
         },
         as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('data', 'theme', 'name')).to eq('Board Room')
    expect(workspace.default_visualization_theme&.name).to eq('Board Room')
  end
end
