# frozen_string_literal: true

class ApplicationController < ActionController::Base
  helper_method :workspace_role_for,
                :can_manage_workspace_settings?,
                :can_manage_workspace_members?,
                :can_manage_data_sources?,
                :can_write_queries?,
                :can_destroy_query?,
                :can_write_dashboards?,
                :can_destroy_dashboards?

  protected

  def require_authentication!
    redirect_to auth_login_index_path unless current_user
  end

  def redirect_authenticated_users_to_app!
    redirect_to app_workspaces_path if current_user
  end

  def current_user
    @current_user ||= User.find_by(id: session[:current_user_id])
  end

  def workspace_role_for(workspace:)
    workspace.members.find_by(user_id: current_user.id)&.role
  end

  def can_manage_workspace_settings?(workspace:)
    [Member::Roles::OWNER, Member::Roles::ADMIN].include?(workspace_role_for(workspace:))
  end

  def can_manage_workspace_members?(workspace:)
    can_manage_workspace_settings?(workspace:)
  end

  def can_manage_data_sources?(workspace:)
    can_manage_workspace_settings?(workspace:)
  end

  def can_write_queries?(workspace:)
    !workspace_role_for(workspace:).in?([nil, Member::Roles::READ_ONLY])
  end

  def can_destroy_query?(workspace:, query:)
    role = workspace_role_for(workspace:)
    return false if role.nil? || role == Member::Roles::READ_ONLY
    return true if [Member::Roles::OWNER, Member::Roles::ADMIN].include?(role)

    query.author_id == current_user.id
  end

  def can_write_dashboards?(workspace:)
    can_write_queries?(workspace:)
  end

  def can_destroy_dashboards?(workspace:)
    [Member::Roles::OWNER, Member::Roles::ADMIN].include?(workspace_role_for(workspace:))
  end

  def deny_workspace_access!(workspace:, fallback_tab: nil)
    flash[:toast] = {
      type: 'error',
      title: I18n.t('toasts.workspaces.access_forbidden.title'),
      body: I18n.t('toasts.workspaces.access_forbidden.body')
    }

    if fallback_tab
      redirect_to app_workspace_path(workspace, tab: fallback_tab)
    else
      redirect_to app_workspaces_path
    end
  end
end
