# frozen_string_literal: true

module App
  module Workspaces
    class MembersController < ApplicationController # rubocop:disable Metrics/ClassLength
      RESEND_COOLDOWN = 10.minutes

      before_action :require_authentication!
      before_action :authorize_manage_members!

      def create
        return reject_owner_invite if inviting_owner_without_permission?
        return reject_existing_member if already_a_member?

        create_invite!
        flash[:toast] = invite_success_toast
        redirect_to_team_tab
      rescue ActiveRecord::RecordInvalid => e
        handle_invite_failure(message: "Workspace invite failed validation: #{e.message}")
      rescue StandardError => e
        handle_invite_failure(message: "Workspace invite failed: #{e.class} #{e.message}")
      end

      def update
        return redirect_to_team_tab unless allowed_to_manage_member?
        return reject_invalid_role_change unless role_change_allowed?

        update_member_role!
      rescue StandardError => e
        handle_role_update_failure(error: e)
      end

      def destroy
        return redirect_to_team_tab if member.owner?
        return redirect_to_team_tab unless allowed_to_manage_member?

        remove_member_with_notification!
        flash[:toast] = member_deleted_toast
        redirect_to_team_tab
      end

      def resend # rubocop:disable Metrics/AbcSize
        return reject_unresendable_member unless resend_allowed?
        return reject_resend_cooldown if resend_cooldown_active?

        resend_invite!
        flash[:toast] = invite_resent_toast
        redirect_to_team_tab
      rescue StandardError => e
        Rails.logger.error("Workspace invite resend failed: #{e.class} #{e.message}")
        flash[:toast] = invite_resend_failed_toast
        redirect_to_team_tab
      end

      private

      def allowed_to_manage_member?
        workspace_role_for(workspace:) < member.role
      end

      def resend_allowed?
        !member.owner? && allowed_to_manage_member? && member.pending?
      end

      def reject_unresendable_member
        redirect_to_team_tab
      end

      def resend_invite!
        WorkspaceInvitationService.new(workspace:).resend!(member:)
      end

      def resend_cooldown_active?
        member.updated_at > RESEND_COOLDOWN.ago
      end

      def reject_resend_cooldown
        flash[:toast] = resend_cooldown_toast
        redirect_to_team_tab
      end

      def inviting_owner_without_permission?
        invite_params[:role].to_i == Member::Roles::OWNER && !current_user_owner?
      end

      def current_user_owner?
        workspace_role_for(workspace:) == Member::Roles::OWNER
      end

      def reject_owner_invite
        flash[:toast] = invite_owner_role_not_allowed_toast
        redirect_to_team_tab
      end

      def reject_existing_member
        flash[:toast] = invite_existing_member_toast
        redirect_to_team_tab
      end

      def reject_invalid_role_change
        flash[:toast] = member_role_update_failed_toast
        redirect_to_team_tab
      end

      def update_member_role!
        member.update!(role: role_change_params[:role].to_i)
        flash[:toast] = member_role_updated_toast
        redirect_to_team_tab
      end

      def handle_role_update_failure(error:)
        Rails.logger.error("Workspace member role change failed: #{error.class} #{error.message}")
        flash[:toast] = member_role_update_failed_toast
        redirect_to_team_tab
      end

      def handle_invite_failure(message:)
        Rails.logger.error(message)
        flash[:toast] = invite_error_toast
        redirect_to_team_tab
      end

      def remove_member_with_notification!
        removed_user = member.user
        removed_member_was_accepted = member.status == Member::Status::ACCEPTED

        member.destroy
        notify_member_removed(user: removed_user) if removed_member_was_accepted
      end

      def notify_member_removed(user:)
        WorkspaceMailer.workspace_member_removed(user:, workspace_name: workspace.name).deliver_now
      rescue StandardError => e
        Rails.logger.error("Workspace member removal notification failed for user #{user.id}: #{e.class} #{e.message}")
      end

      def already_a_member?
        user = User.find_by(email: invite_params[:email])
        return false unless user

        user.member_of?(workspace:)
      end

      def redirect_to_team_tab
        redirect_to app_workspace_settings_path(workspace, tab: 'team')
      end

      def member
        @member ||= workspace.members.find(params[:id])
      end

      def workspaces
        @workspaces ||= current_user.workspaces
      end

      def workspace
        @workspace ||= find_workspace_for_current_user!(param_key: :workspace_id)
      end

      def invite_params
        params.permit(:first_name, :last_name, :email, :role)
      end

      def role_change_params
        params.permit(:role)
      end

      def role_change_allowed?
        editable_role_options.include?(role_change_params[:role].to_i)
      end

      def editable_role_options
        roles = [Member::Roles::ADMIN, Member::Roles::USER, Member::Roles::READ_ONLY]
        roles.unshift(Member::Roles::OWNER) if current_user_owner?
        roles
      end

      def create_invite!
        WorkspaceInvitationService.new(workspace:).invite!(
          invited_by: current_user,
          first_name: invite_params[:first_name],
          last_name: invite_params[:last_name],
          email: invite_params[:email],
          role: invite_params[:role].to_i
        )
      end

      def invite_success_toast
        {
          type: 'success',
          title: I18n.t('toasts.workspaces.members.invited.title'),
          body: I18n.t('toasts.workspaces.members.invited.body', name: invitee_name)
        }
      end

      def invite_error_toast
        {
          type: 'error',
          title: I18n.t('toasts.workspaces.members.invite_failed.title'),
          body: I18n.t('toasts.workspaces.members.invite_failed.body')
        }
      end

      def invite_existing_member_toast
        {
          type: 'information',
          title: I18n.t('toasts.workspaces.members.already_member.title'),
          body: I18n.t('toasts.workspaces.members.already_member.body')
        }
      end

      def invite_owner_role_not_allowed_toast
        {
          type: 'error',
          title: I18n.t('toasts.workspaces.members.owner_invite_forbidden.title'),
          body: I18n.t('toasts.workspaces.members.owner_invite_forbidden.body')
        }
      end

      def invite_resent_toast
        {
          type: 'success',
          title: I18n.t('toasts.workspaces.members.resent.title'),
          body: I18n.t('toasts.workspaces.members.resent.body', name: member.user.full_name)
        }
      end

      def invite_resend_failed_toast
        {
          type: 'error',
          title: I18n.t('toasts.workspaces.members.resend_failed.title'),
          body: I18n.t('toasts.workspaces.members.resend_failed.body')
        }
      end

      def resend_cooldown_toast
        {
          type: 'information',
          title: I18n.t('toasts.workspaces.members.resend_blocked.title'),
          body: I18n.t('toasts.workspaces.members.resend_blocked.body', minutes: RESEND_COOLDOWN.in_minutes.to_i)
        }
      end

      def member_deleted_toast
        {
          type: 'success',
          title: I18n.t('toasts.workspaces.members.deleted.title'),
          body: I18n.t('toasts.workspaces.members.deleted.body', name: member.user.full_name)
        }
      end

      def member_role_updated_toast
        {
          type: 'success',
          title: I18n.t('toasts.workspaces.members.role_updated.title'),
          body: I18n.t(
            'toasts.workspaces.members.role_updated.body',
            name: member.user.full_name,
            role: member.role_name
          )
        }
      end

      def member_role_update_failed_toast
        {
          type: 'error',
          title: I18n.t('toasts.workspaces.members.role_update_failed.title'),
          body: I18n.t('toasts.workspaces.members.role_update_failed.body')
        }
      end

      def invitee_name
        existing_user = User.find_by(email: invite_params[:email])
        return existing_user.full_name if existing_user

        "#{invite_params[:first_name]} #{invite_params[:last_name]}".strip
      end

      def authorize_manage_members!
        return if can_manage_workspace_members?(workspace:)

        deny_workspace_access!(workspace:, fallback_path: app_workspace_path(workspace))
      end
    end # rubocop:enable Metrics/ClassLength
  end
end
