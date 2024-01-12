# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get 'ping' => 'rails/health#show', as: :rails_health_check

  root 'home#index'

  resources :about, only: %i[index]

  namespace :auth do
    resources :signout, only: %i[index]
    resources :login, only: %i[index new create] do
      collection { get 'resend' }
    end
    resources :signup, only: %i[index new create] do
      collection { get 'resend' }
    end
  end

  namespace :app do
    resources :data_sources, only: %i[index new create] do
      member { get 'set_up' }
      resources :queries, only: %i[index show create update], controller: 'data_sources/queries'
    end
  end
end
