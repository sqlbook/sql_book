# frozen_string_literal: true

module App
  module Workspaces
    class MembersController < ApplicationController
      before_action :require_authentication!

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
    end
  end
end
