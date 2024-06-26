# frozen_string_literal: true

module PageHelper
  def body_class
    # Provide a way to target specific pages and actions, e.g.
    # home-index
    # auth-signup-index
    "#{controller_path.gsub('/', '-')}-#{action_name}"
  end

  def signup_page?
    request.path == auth_signup_index_path
  end

  def login_page?
    request.path == auth_login_index_path
  end

  def signed_in?
    session[:current_user_id].present?
  end

  def app_page?
    request.path.start_with?('/app/')
  end
end
