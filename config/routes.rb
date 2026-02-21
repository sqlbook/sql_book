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

  namespace :app do
    resource :account_settings, only: %i[show update], path: 'account-settings', controller: 'account_settings'
    get 'account-settings/verify-email/:token',
        to: 'account_settings#verify_email',
        as: :verify_email_account_settings

    get 'workspaces/:id/workspace-settings', to: 'workspaces/settings#show', as: :workspace_settings
    patch 'workspaces/:id/workspace-settings', to: 'workspaces/settings#update', as: nil

    resources :workspaces, except: %i[edit update] do
      resources :queries, only: %i[index], controller: 'workspaces/queries'
      resources :dashboards, controller: 'workspaces/dashboards'
      resources :members, only: %i[create update destroy], controller: 'workspaces/members' do
        member { post 'resend' }
      end

      resources :data_sources, controller: 'workspaces/data_sources' do
        resources :set_up, only: %i[index], controller: 'workspaces/data_sources/set_up'
        resources :queries, controller: 'workspaces/data_sources/queries' do
          member { put 'chart_config' }
        end
      end
    end
  end
end
