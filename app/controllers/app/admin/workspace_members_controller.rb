# frozen_string_literal: true

module App
  module Admin
    class WorkspaceMembersController < BaseController
      VALID_ROLES = [
        Member::Roles::OWNER,
        Member::Roles::ADMIN,
        Member::Roles::USER,
        Member::Roles::READ_ONLY
      ].freeze

      before_action :load_workspace
      before_action :load_member

      attr_reader :member, :workspace

      def update
        return redirect_with_error(body: 'Please choose a valid role.') unless valid_role?
        return redirect_with_error(body: 'This workspace must keep at least one owner.') if demoting_last_owner?

        apply_role_update!
        redirect_with_success(body: "#{member.user.full_name} is now #{member.role_name}.")
      rescue StandardError => e
        handle_action_error(action: 'role update', error: e)
      end

      def destroy
        return redirect_with_error(body: 'This workspace must keep at least one owner.') if removing_last_owner?

        removed_user_name = destroy_member!
        redirect_with_success(
          title: 'Workspace member removed',
          body: "#{removed_user_name} was removed from this workspace."
        )
      rescue StandardError => e
        handle_action_error(action: 'removal', error: e)
      end

      private

      def apply_role_update!
        member.update!(role: requested_role)
      end

      def destroy_member!
        removed_user_name = member.user.full_name
        member.destroy!
        removed_user_name
      end

      def redirect_with_success(body:, title: 'Workspace member updated')
        flash[:toast] = {
          type: 'success',
          title:,
          body:
        }
        redirect_to return_path
      end

      def redirect_with_error(body:)
        flash[:toast] = {
          type: 'error',
          title: 'Workspace member update failed',
          body:
        }
        redirect_to return_path
      end

      def load_workspace
        @workspace = Workspace.find(params[:workspace_id])
      end

      def load_member
        @member = workspace.members.includes(:user).find(params[:id])
      end

      def requested_role
        @requested_role ||= role_params[:role].to_i
      end

      def valid_role?
        VALID_ROLES.include?(requested_role)
      end

      def demoting_last_owner?
        member.owner? && requested_role != Member::Roles::OWNER && owner_count <= 1
      end

      def removing_last_owner?
        member.owner? && owner_count <= 1
      end

      def owner_count
        workspace.members.accepted.where(role: Member::Roles::OWNER).count
      end

      def role_params
        params.permit(:role)
      end

      def return_path
        app_admin_workspaces_path(q: params[:q], workspace_id: workspace.id)
      end

      def handle_action_error(action:, error:)
        Rails.logger.error("Admin workspace member #{action} failed: #{error.class} #{error.message}")
        flash[:toast] = generic_error_toast
        redirect_to return_path
      end
    end
  end
end
