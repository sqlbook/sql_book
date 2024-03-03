# frozen_string_literal: true

module App
  module Workspaces
    class MembersController < ApplicationController
      before_action :require_authentication!

      def create
        return redirect_to_team_tab if invite_params[:role].to_i == Member::Roles::OWNER
        return redirect_to_team_tab if already_a_member?

        create_invite!

        redirect_to_team_tab
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
          first_name: invite_params[:first_name],
          last_name: invite_params[:last_name],
          email: invite_params[:email],
          role: invite_params[:role].to_i
        )
      end
    end
  end
end
