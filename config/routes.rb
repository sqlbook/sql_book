# frozen_string_literal: true

Rails.application.routes.draw do # rubocop:disable Metrics/BlockLength
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get 'ping' => 'rails/health#show', as: :rails_health_check

  root 'home#index'

  resources :about, only: %i[index]

  namespace :auth do
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
    resources :workspaces, only: %i[index show new create] do
      resources :queries, only: %i[index], controller: 'workspaces/queries'
      resources :dashboards, only: %i[index], controller: 'workspaces/dashboards'
      resources :members, only: %i[create destroy], controller: 'workspaces/members'

      resources :data_sources, controller: 'workspaces/data_sources' do
        resources :set_up, only: %i[index], controller: 'workspaces/data_sources/set_up'
        resources :queries, only: %i[index show create update], controller: 'workspaces/data_sources/queries' do
          member { put 'chart_config' }
        end
      end
    end
  end
end
