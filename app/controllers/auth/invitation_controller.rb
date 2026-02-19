# frozen_string_literal: true

module Auth
  class InvitationController < ApplicationController
    def show
      return redirect_for_invalid_invitation unless member

      @member = member
    end

    def accept
      return redirect_for_invalid_invitation unless member
      return reject_accept_without_terms unless accepted_terms?

      accept_invitation!
      redirect_to post_accept_redirect_path
    end

    def reject
      return redirect_for_invalid_invitation unless member

      WorkspaceInvitationService.new(workspace: member.workspace).reject!(member:)
      redirect_to root_path
    end

    private

    def member
      @member ||= Member.find_by(invitation: params[:id])
    end

    def accepted_terms?
      params[:accept_terms] == '1'
    end

    def reject_accept_without_terms
      flash[:alert] = I18n.t('auth.must_accept_terms')
      redirect_to auth_invitation_path(params[:id])
    end

    def redirect_for_invalid_invitation
      flash[:toast] = {
        type: 'information',
        title: I18n.t('toasts.invitation.invalid.title'),
        body: I18n.t('toasts.invitation.invalid.body')
      }
      redirect_to root_path
    end

    def capture_terms_acceptance!(user:)
      user.update!(
        terms_accepted_at: Time.current,
        terms_version: User::CURRENT_TERMS_VERSION
      )
    end

    def accept_invitation!
      capture_terms_acceptance!(user: member.user)
      WorkspaceInvitationService.new(workspace: member.workspace).accept!(member:)
      authenticate_invited_user!
    end

    def authenticate_invited_user!
      reset_session
      session[:current_user_id] = member.user.id
    end

    def post_accept_redirect_path
      return app_workspace_path(member.workspace) if can_manage_workspace_settings?(workspace: member.workspace)

      app_workspace_queries_path(member.workspace)
    end
  end
end
