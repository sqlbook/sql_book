# frozen_string_literal: true

module App
  module Admin
    class UsersController < BaseController # rubocop:disable Metrics/ClassLength
      before_action :load_users
      before_action :load_target_user!, only: %i[destroy]

      def index
        selected_user_id = params[:user_id].to_s.presence
        @selected_user = selected_user_id.present? ? user_for_panel(selected_user_id:) : nil
        @selected_user_owned_workspace_rows = selected_user_owned_workspace_rows
      end

      def destroy
        return reject_self_delete if deleting_current_user?

        result = AccountDeletionService.new(
          user: @target_user,
          workspace_actions: workspace_actions_params,
          send_emails: false
        ).call

        return reject_unresolved_workspace_actions if result.error_key == :account_delete_unresolved_workspaces
        return reject_user_delete_failed unless result.success?

        flash[:toast] = {
          type: 'success',
          title: 'User deleted',
          body: "#{@target_user.full_name} and related workspace changes were processed."
        }
        redirect_to app_admin_users_path(q: params[:q])
      end

      private

      def load_users
        scope = User.includes(members: :workspace).order(created_at: :desc)
        @users = search_query.present? ? scope.where(user_search_query, query: "%#{search_query}%") : scope
      end

      def user_search_query
        <<~SQL.squish
          LOWER(users.first_name) LIKE :query
          OR LOWER(users.last_name) LIKE :query
          OR LOWER(users.email) LIKE :query
        SQL
      end

      def search_query
        @search_query ||= params[:q].to_s.strip.downcase.presence
      end

      def load_target_user!
        @target_user = User.includes(members: { workspace: { members: :user } }).find(params[:id])
      end

      def deleting_current_user?
        current_user.id == @target_user.id
      end

      def reject_self_delete
        flash[:toast] = {
          type: 'error',
          title: 'User delete blocked',
          body: 'You cannot delete your own super-admin account from this screen.'
        }
        redirect_to app_admin_users_path(q: params[:q], user_id: params[:id])
      end

      def workspace_actions_params
        raw_workspace_actions = params[:workspace_actions]
        return {} unless raw_workspace_actions.respond_to?(:to_unsafe_h)

        raw_workspace_actions.to_unsafe_h.transform_values { |value| value.to_s.strip }
      end

      def reject_unresolved_workspace_actions
        flash[:toast] = {
          type: 'error',
          title: 'Could not delete user',
          body: 'Please choose an outcome for each owned workspace before confirming delete.'
        }
        redirect_to app_admin_users_path(q: params[:q], user_id: params[:id])
      end

      def reject_user_delete_failed
        flash[:toast] = {
          type: 'error',
          title: 'Could not delete user',
          body: 'Please try again. If the problem continues, contact hello@sqlbook.com.'
        }
        redirect_to app_admin_users_path(q: params[:q], user_id: params[:id])
      end

      def owned_workspace_rows_for(user:)
        user.members
          .accepted
          .where(role: Member::Roles::OWNER)
          .includes(workspace: { members: :user })
          .map(&:workspace)
          .uniq(&:id)
          .sort_by { |workspace| workspace.name.downcase }
          .map do |workspace|
            {
              workspace:,
              eligible_members: eligible_transfer_members_for(workspace:, user:)
            }
          end
      end

      def selected_user_owned_workspace_rows
        return [] if @selected_user.blank?

        owned_workspace_rows_for(user: @selected_user)
      end

      def eligible_transfer_members_for(workspace:, user:)
        workspace.members
          .select { |member| member.status == Member::Status::ACCEPTED && member.user_id != user.id }
          .sort_by { |member| [member.user.first_name, member.user.last_name] }
      end

      def user_for_panel(selected_user_id:)
        @users.find { |user| user.id == selected_user_id.to_i } ||
          User.includes(members: { workspace: :members }).find_by(id: selected_user_id)
      end
    end # rubocop:enable Metrics/ClassLength
  end
end
