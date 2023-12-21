# frozen_string_literal: true

module Auth
  class SignoutController < ApplicationController
    def index
      session[:current_user_id] = nil
      redirect_to root_path
    end
  end
end
