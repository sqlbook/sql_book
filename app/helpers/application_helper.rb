# frozen_string_literal: true

module ApplicationHelper
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

  def class_names(*class_names, **conditional_class_names)
    conditionals = conditional_class_names.each_with_object([]) do |(key, value), memo|
      memo.push(key) if value
    end

    class_names.concat(conditionals)
  end

  def active_tab?(tab:, default_selected: false)
    return true if default_selected && params['tab'].nil?

    current_page?(tab:, check_parameters: true)
  end
end
