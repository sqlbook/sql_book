# frozen_string_literal: true

module Auth
  class InvitationController < ApplicationController
    def show
      member = Member.find_by(invitation: params[:id])

      return render :show unless member

      WorkspaceInvitationService.new(workspace: member.workspace).accept!(member:)

      session[:current_user_id] = member.user.id
      redirect_to app_workspace_path(member.workspace)
    end
  end
end
