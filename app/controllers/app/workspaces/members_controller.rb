# frozen_string_literal: true

module App
  module Workspaces
    class MembersController < ApplicationController
      before_action :require_authentication!

      def create
        return reject_owner_invite if inviting_owner?
        return reject_existing_member if already_a_member?

        create_invite!
        flash[:toast] = invite_success_toast
        redirect_to_team_tab
      rescue ActiveRecord::RecordInvalid => e
        handle_invite_failure(message: "Workspace invite failed validation: #{e.message}")
      rescue StandardError => e
        handle_invite_failure(message: "Workspace invite failed: #{e.class} #{e.message}")
      end

      def destroy
        return redirect_to_team_tab if member.owner?
        return redirect_to_team_tab unless allowed_to_destroy_member?

        member.destroy

        redirect_to_team_tab
      end

      private

      def allowed_to_destroy_member?
        workspace.role_for(user: current_user) < member.role
      end

      def inviting_owner?
        invite_params[:role].to_i == Member::Roles::OWNER
      end

      def reject_owner_invite
        flash[:toast] = invite_owner_role_not_allowed_toast
        redirect_to_team_tab
      end

      def reject_existing_member
        flash[:toast] = invite_existing_member_toast
        redirect_to_team_tab
      end

      def handle_invite_failure(message:)
        Rails.logger.error(message)
        flash[:toast] = invite_error_toast
        redirect_to_team_tab
      end

      def already_a_member?
        user = User.find_by(email: invite_params[:email])
        return false unless user

        user.member_of?(workspace:)
      end

      def redirect_to_team_tab
        redirect_to app_workspace_path(workspace, tab: 'team')
      end

      def member
        @member ||= workspace.members.find(params[:id])
      end

      def workspaces
        @workspaces ||= current_user.workspaces
      end

      def workspace
        @workspace ||= workspaces.find(params[:workspace_id])
      end

      def invite_params
        params.permit(:first_name, :last_name, :email, :role)
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
          body: I18n.t('toasts.workspaces.members.invited.body', email: invite_params[:email])
        }
      end

      def invite_error_toast
        {
          type: 'error',
          title: I18n.t('toasts.workspaces.members.invite_failed.title'),
          body: I18n.t('toasts.workspaces.members.invite_failed.body'),
          actions: [
            { label: '[Try again]', path: app_workspace_path(workspace, tab: 'team'), variant: 'primary' }
          ]
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
    end
  end
end
