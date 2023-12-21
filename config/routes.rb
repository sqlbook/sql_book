# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get 'ping' => 'rails/health#show', as: :rails_health_check

  root 'home#index'

  namespace :auth do
    resources :login, only: %i[index new create]
    resources :signout, only: %i[index]
    resources :signup, only: %i[index new create]
  end

  namespace :app do
    resources :dashboard, only: %i[index]
  end
end
