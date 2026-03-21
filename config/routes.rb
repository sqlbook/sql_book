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

  namespace :api do
    namespace :v1 do
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
    end
  end

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

    resources :workspaces, except: %i[edit update] do
      resources :chat_threads,
                only: %i[index create update destroy],
                path: 'chat/threads',
                controller: 'workspaces/chat_threads'
      get 'chat/messages', to: 'workspaces/chat_messages#index', as: :chat_messages
      post 'chat/messages', to: 'workspaces/chat_messages#create'
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
        resources :queries, controller: 'workspaces/data_sources/queries' do
          member { put 'chart_config' }
        end
      end
    end
  end # rubocop:enable Metrics/BlockLength
end
