# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'App::Workspaces::Settings', type: :request do
  describe 'GET /app/workspaces/:id/settings' do
    let(:owner) { create(:user) }
    let(:workspace) { create(:workspace_with_owner, owner:) }

    before { sign_in(owner) }

    it 'renders localized team table headings in English' do
      get app_workspace_settings_path(workspace, tab: 'team')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('app.workspaces.settings.team.table.name'))
      expect(response.body).to include(I18n.t('app.workspaces.settings.team.table.role'))
      expect(response.body).to include(I18n.t('app.workspaces.settings.team.table.status'))
      expect(response.body).to include(I18n.t('app.workspaces.settings.team.table.actions'))
    end

    it 'renders localized member role labels in Spanish' do
      owner.update!(preferred_locale: 'es')

      get app_workspace_settings_path(workspace, tab: 'team')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('app.workspaces.settings.team.table.status', locale: :es))
      expect(response.body).to include(I18n.t('models.member.roles.owner', locale: :es))
    end

    it 'marks the current user in the team table' do
      get app_workspace_settings_path(workspace, tab: 'team')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("#{owner.full_name} #{I18n.t('app.workspaces.settings.team.table.you')}")
    end

    it 'renders the Branding tab between Team and Subscription' do
      get app_workspace_settings_path(workspace)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('app.workspaces.settings.tabs.team'))
      expect(response.body).to include(I18n.t('app.workspaces.settings.tabs.branding'))
      expect(response.body).to include(I18n.t('app.workspaces.settings.tabs.subscription'))
    end

    it 'shows the built-in Default Theming entry in the branding library' do
      get app_workspace_settings_path(workspace, tab: 'branding')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Default Theming')
      expect(response.body).to include(I18n.t('app.workspaces.settings.branding.table.read_only'))
      expect(response.body).to include(I18n.t('app.workspaces.settings.branding.themes_title'))
    end

    it 'opens a selected theme in the branding side panel with mode tabs' do
      get app_workspace_settings_path(
        workspace,
        tab: 'branding',
        theme: Visualizations::SystemTheme::REFERENCE_KEY
      )

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('app.workspaces.settings.branding.panel.tabs.theme_settings'))
      expect(response.body).to include(I18n.t('app.workspaces.settings.branding.panel.tabs.dark_mode'))
      expect(response.body).to include(I18n.t('app.workspaces.settings.branding.panel.tabs.light_mode'))
    end
  end
end
