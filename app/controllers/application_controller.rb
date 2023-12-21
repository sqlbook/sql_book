# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protected

  def require_authentication!
    redirect_to auth_login_index_path unless current_user
  end

  def redirect_authenticated_users_to_app!
    redirect_to app_dashboard_index_path if current_user
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:current_user_id])
  end
end
