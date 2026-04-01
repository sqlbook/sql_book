# frozen_string_literal: true

Rails.application.routes.draw do # rubocop:disable Metrics/BlockLength
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  mount ActionCable.server => '/cable'
  mount ActionCable.server => '/events/in'

  get 'up' => 'rails/health#show', as: :rails_health_check

  root 'home#index'

  resources :about, only: %i[index]
  get 'terms-of-service', to: 'legal#terms_of_service'
  get 'privacy-policy', to: 'legal#privacy_policy'
  get 'dev/api', to: 'dev/api_docs#show'
  get 'dev/api/openapi.json', to: 'dev/api_docs#openapi'

  namespace :api do # rubocop:disable Metrics/BlockLength
    namespace :v1 do # rubocop:disable Metrics/BlockLength
      patch 'workspaces/:workspace_id', to: 'workspaces#update'
      delete 'workspaces/:workspace_id', to: 'workspaces#destroy'
      get 'workspaces/:workspace_id/members', to: 'members#index'
      post 'workspaces/:workspace_id/members', to: 'members#create'
      post 'workspaces/:workspace_id/members/resend-invite', to: 'members#resend_invite'
      patch 'workspaces/:workspace_id/members/:id/role', to: 'members#update_role'
      delete 'workspaces/:workspace_id/members/:id', to: 'members#destroy'
      get 'workspaces/:workspace_id/data-sources', to: 'data_sources#index'
      post 'workspaces/:workspace_id/data-sources/validate-connection', to: 'data_sources#validate_connection'
      post 'workspaces/:workspace_id/data-sources', to: 'data_sources#create'
      get 'workspaces/:workspace_id/queries', to: 'queries#index'
      post 'workspaces/:workspace_id/queries/run', to: 'queries#run'
      post 'workspaces/:workspace_id/queries', to: 'queries#create'
      patch 'workspaces/:workspace_id/queries/:id', to: 'queries#update'
      delete 'workspaces/:workspace_id/queries/:id', to: 'queries#destroy'
      get 'workspaces/:workspace_id/queries/:query_id/visualizations', to: 'query_visualizations#index'
      get 'workspaces/:workspace_id/queries/:query_id/visualizations/:chart_type', to: 'query_visualizations#show'
      patch 'workspaces/:workspace_id/queries/:query_id/visualizations/:chart_type', to: 'query_visualizations#update'
      put 'workspaces/:workspace_id/queries/:query_id/visualizations/:chart_type', to: 'query_visualizations#update'
      delete 'workspaces/:workspace_id/queries/:query_id/visualizations/:chart_type', to: 'query_visualizations#destroy'
      get 'workspaces/:workspace_id/visualization-themes', to: 'visualization_themes#index'
      post 'workspaces/:workspace_id/visualization-themes', to: 'visualization_themes#create'
      get 'workspaces/:workspace_id/visualization-themes/:id', to: 'visualization_themes#show'
      patch 'workspaces/:workspace_id/visualization-themes/:id', to: 'visualization_themes#update'
      delete 'workspaces/:workspace_id/visualization-themes/:id', to: 'visualization_themes#destroy'
      post 'workspaces/:workspace_id/visualization-themes/duplicate', to: 'visualization_themes#duplicate'
      patch 'workspaces/:workspace_id/visualization-themes/:id/default', to: 'visualization_themes#set_default'
      patch 'workspaces/:workspace_id/chat-threads/:id', to: 'chat_threads#update'
    end # rubocop:enable Metrics/BlockLength
  end # rubocop:enable Metrics/BlockLength

  namespace :auth do
    resources :invitation, only: %i[show] do
      member do
        post 'accept'
        post 'reject'
      end
    end
    resources :signout, only: %i[index]
    resources :login, only: %i[index new create] do
      collection do
        get 'magic_link', to: 'login#create'
        get 'resend'
      end
    end
    resources :signup, only: %i[index new create] do
      collection do
        get 'magic_link', to: 'signup#create'
        get 'resend'
      end
    end
  end

  namespace :app do # rubocop:disable Metrics/BlockLength
    get 'chat-components', to: 'chat_components#show'

    namespace :admin do
      root to: 'dashboard#index'
      get '/', to: 'dashboard#index', as: :dashboard
      resources :workspaces, only: %i[index] do
        resources :members, only: %i[update destroy], controller: 'workspace_members'
      end
      resources :users, only: %i[index destroy]
      patch 'translations', to: 'translations#update'
      resources :translations, only: %i[index] do
        member do
          post 'translate-missing', to: 'translations#translate_missing'
          get 'history', to: 'translations#history'
        end
      end
    end

    resource :account_settings, only: %i[show update destroy], path: 'account-settings', controller: 'account_settings'
    get 'account-settings/verify-email/:token',
        to: 'account_settings#verify_email',
        as: :verify_email_account_settings

    get 'workspaces/:id/workspace-settings', to: 'workspaces/settings#show', as: :workspace_settings
    patch 'workspaces/:id/workspace-settings', to: 'workspaces/settings#update', as: nil
    post 'workspaces/:id/workspace-settings/branding/themes',
         to: 'workspaces/settings/visualization_themes#create',
         as: :workspace_visualization_themes
    patch 'workspaces/:id/workspace-settings/branding/themes/:theme_id',
          to: 'workspaces/settings/visualization_themes#update',
          as: :workspace_visualization_theme
    delete 'workspaces/:id/workspace-settings/branding/themes/:theme_id',
           to: 'workspaces/settings/visualization_themes#destroy',
           as: :delete_workspace_visualization_theme
    post 'workspaces/:id/workspace-settings/branding/themes/duplicate',
         to: 'workspaces/settings/visualization_themes#duplicate',
         as: :duplicate_workspace_visualization_theme
    patch 'workspaces/:id/workspace-settings/branding/themes/:theme_id/default',
          to: 'workspaces/settings/visualization_themes#set_default',
          as: :default_workspace_visualization_theme
    post 'workspaces/:workspace_id/query-editor/run',
         to: 'workspaces/query_editor#run',
         as: :workspace_query_editor_run
    post 'workspaces/:workspace_id/query-editor/save',
         to: 'workspaces/query_editor#save',
         as: :workspace_query_editor_save

    resources :workspaces, except: %i[edit update] do # rubocop:disable Metrics/BlockLength
      resources :chat_threads,
                only: %i[index create update destroy],
                path: 'chat/threads',
                controller: 'workspaces/chat_threads'
      get 'chat/messages', to: 'workspaces/chat_messages#index', as: :chat_messages
      post 'chat/messages', to: 'workspaces/chat_messages#create'
      post 'chat/query-cards/:message_id/save', to: 'workspaces/chat_query_cards#save', as: :chat_query_card_save
      post 'chat/query-cards/:message_id/save-as-new',
           to: 'workspaces/chat_query_cards#save_as_new',
           as: :chat_query_card_save_as_new
      post 'chat/query-cards/:message_id/save-changes',
           to: 'workspaces/chat_query_cards#save_changes',
           as: :chat_query_card_save_changes
      post 'chat/actions/:id/confirm', to: 'workspaces/chat_actions#confirm', as: :chat_action_confirm
      post 'chat/actions/:id/cancel', to: 'workspaces/chat_actions#cancel', as: :chat_action_cancel

      resources :queries, only: %i[index], controller: 'workspaces/queries'
      resources :dashboards, controller: 'workspaces/dashboards'
      resources :members, only: %i[create update destroy], controller: 'workspaces/members' do
        member { post 'resend' }
      end

      resources :data_sources, controller: 'workspaces/data_sources' do
        collection do
          post 'validate_connection'
        end
        resources :set_up, only: %i[index], controller: 'workspaces/data_sources/set_up'
        resources :queries, only: %i[index show destroy], controller: 'workspaces/data_sources/queries' do
          resources :visualizations,
                    only: %i[show update destroy],
                    param: :chart_type,
                    controller: 'workspaces/data_sources/query_visualizations'
        end
      end
    end # rubocop:enable Metrics/BlockLength
  end # rubocop:enable Metrics/BlockLength
end
