# frozen_string_literal: true

class ApplicationController < ActionController::Base
  class WorkspaceAccessDenied < StandardError; end

  rescue_from WorkspaceAccessDenied, with: :redirect_for_workspace_access_denied

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
    return redirect_to auth_login_index_path unless current_user

    show_pending_invitation_toast_if_needed
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

  def find_workspace_for_current_user!(param_key:)
    workspace = Workspace.find_by(id: params[param_key])
    raise WorkspaceAccessDenied if workspace.nil? || !current_user.member_of?(workspace:)

    workspace
  end

  def redirect_for_workspace_access_denied
    flash[:toast] = {
      type: 'error',
      title: I18n.t('toasts.workspaces.unavailable.title'),
      body: I18n.t('toasts.workspaces.unavailable.body')
    }
    redirect_to app_workspaces_path
  end

  def show_pending_invitation_toast_if_needed
    return unless request.get?
    return unless controller_path.start_with?('app/')
    return if flash[:toast].present? || flash[:toasts].present?

    pending_member = current_user.members.pending.includes(:workspace).where.not(invitation: nil).first
    return unless pending_member

    flash.now[:toasts] = Array(flash.now[:toasts]) + [pending_invitation_toast(member: pending_member)]
  end

  def pending_invitation_toast(member:)
    {
      type: 'information',
      title: I18n.t('toasts.invitation.pending.title'),
      body: I18n.t('toasts.invitation.pending.body', workspace_name: member.workspace.name),
      actions: [
        { label: '[Accept invitation]', path: auth_invitation_path(member.invitation), variant: 'primary' },
        { label: 'Reject', path: reject_auth_invitation_path(member.invitation), method: 'post', variant: 'secondary' }
      ]
    }
  end
end
