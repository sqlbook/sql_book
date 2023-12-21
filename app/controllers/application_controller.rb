# frozen_string_literal: true

class ApplicationController < ActionController::Base
  def authenticate_user!
    redirect_to auth_login_index_path unless current_user
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:current_user_id])
  end
end
