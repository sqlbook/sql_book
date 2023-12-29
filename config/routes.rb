# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get 'ping' => 'rails/health#show', as: :rails_health_check

  root 'home#index'

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
    resources :dashboard, only: %i[index]
    resources :data_sources, only: %i[show new create] do
      member { get 'set_up' }
    end
  end
end
