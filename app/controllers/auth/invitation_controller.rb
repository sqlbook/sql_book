# frozen_string_literal: true

module Auth
  class InvitationController < ApplicationController
    def show
      @member = member
    end

    def accept
      WorkspaceInvitationService.new(workspace: member.workspace).accept!(member:)
      reset_session
      session[:current_user_id] = member.user.id
      redirect_to app_workspace_path(member.workspace)
    end

    def reject
      WorkspaceInvitationService.new(workspace: member.workspace).reject!(member:)
      redirect_to root_path
    end

    private

    def member
      @member ||= Member.find_by(invitation: params[:id])
    end
  end
end
