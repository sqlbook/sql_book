# frozen_string_literal: true

class ApplicationController < ActionController::Base # rubocop:disable Metrics/ClassLength
  class WorkspaceAccessDenied < StandardError; end

  before_action :set_locale
  before_action :ensure_bootstrap_super_admin!

  rescue_from WorkspaceAccessDenied, with: :redirect_for_workspace_access_denied

  helper_method :workspace_role_for,
                :can_manage_workspace_settings?,
                :can_manage_workspace_members?,
                :can_manage_data_sources?,
                :can_write_queries?,
                :can_destroy_query?,
                :can_write_dashboards?,
                :can_destroy_dashboards?,
                :current_locale

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

  def current_locale
    I18n.locale.to_s
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

  def deny_workspace_access!(workspace:, fallback_tab: nil, fallback_path: nil)
    flash[:toast] = {
      type: 'error',
      title: I18n.t('toasts.workspaces.access_forbidden.title'),
      body: I18n.t('toasts.workspaces.access_forbidden.body')
    }

    if fallback_path
      redirect_to fallback_path
    elsif fallback_tab
      redirect_to app_workspace_settings_path(workspace, tab: fallback_tab)
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
    return unless should_show_pending_invitation_toast?

    pending_member = pending_member_with_invitation
    return unless pending_member

    flash.now[:toasts] = Array(flash.now[:toasts]) + [pending_invitation_toast(member: pending_member)]
  end

  def pending_invitation_toast(member:)
    {
      type: 'information',
      title: I18n.t('toasts.invitation.pending.title'),
      body: I18n.t('toasts.invitation.pending.body', workspace_name: member.workspace.name),
      actions: [
        { label: '[View invitation]', path: auth_invitation_path(member.invitation), variant: 'primary' }
      ]
    }
  end

  def should_show_pending_invitation_toast?
    request.get? && controller_path.start_with?('app/') && flash[:toast].blank? && flash[:toasts].blank?
  end

  def pending_member_with_invitation
    current_user.members.pending.includes(:workspace).where.not(invitation: nil).first
  end

  def generic_error_toast
    {
      type: 'error',
      title: I18n.t('toasts.generic_error.title'),
      body: I18n.t('toasts.generic_error.body')
    }
  end

  def deny_admin_access!
    flash[:toast] = {
      type: 'error',
      title: I18n.t('toasts.admin.access_forbidden.title'),
      body: I18n.t('toasts.admin.access_forbidden.body')
    }
    redirect_to app_workspaces_path
  end

  private

  def set_locale
    locale = resolved_locale
    I18n.locale = locale
    session[:locale] = locale
    persist_detected_locale_for_user!(locale:)
  end

  def ensure_bootstrap_super_admin!
    return unless current_user
    return if current_user.super_admin?
    return unless bootstrap_super_admin_emails.include?(current_user.email)

    current_user.update!(super_admin: true)
  end

  def resolved_locale
    normalize_locale(current_user&.preferred_locale) ||
      normalize_locale(session[:locale]) ||
      detected_locale_from_request ||
      I18n.default_locale.to_s
  end

  def persist_detected_locale_for_user!(locale:)
    return unless current_user
    return if current_user.preferred_locale.present?

    current_user.update!(preferred_locale: locale)
  rescue StandardError => e
    Rails.logger.warn("Unable to persist detected locale for user #{current_user&.id}: #{e.class} #{e.message}")
  end

  def detected_locale_from_request
    accepted = request.env['HTTP_ACCEPT_LANGUAGE'].to_s
    return nil if accepted.blank?

    language = accepted.split(',').map { |item| item.split(';').first.to_s.strip.downcase }.find(&:present?)
    return 'es' if language&.start_with?('es')

    'en'
  end

  def normalize_locale(value)
    normalized = value.to_s.strip.downcase
    return nil if normalized.blank?
    return normalized if User::SUPPORTED_LOCALES.include?(normalized)

    nil
  end

  def bootstrap_super_admin_emails
    @bootstrap_super_admin_emails ||= ENV.fetch('SUPER_ADMIN_BOOTSTRAP_EMAILS', '')
      .split(',')
      .map { |email| email.strip.downcase }
      .compact_blank
  end
end # rubocop:enable Metrics/ClassLength
