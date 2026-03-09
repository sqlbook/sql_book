# frozen_string_literal: true

module Api
  module V1
    class MembersController < Api::BaseController
      def index
        execute_tool(action_type: 'member.list', payload: {})
      end

      def create
        execute_tool(
          action_type: 'member.invite',
          payload: invite_payload
        )
      end

      def resend_invite
        execute_tool(
          action_type: 'member.resend_invite',
          payload: {
            'member_id' => member_id_from_params,
            'email' => params[:email].to_s
          }.compact
        )
      end

      def update_role
        execute_tool(
          action_type: 'member.update_role',
          payload: {
            'member_id' => params[:id].to_i,
            'role' => params[:role].to_i
          }
        )
      end

      def destroy
        execute_tool(
          action_type: 'member.remove',
          payload: {
            'member_id' => params[:id].to_i
          }
        )
      end

      private

      def member_id_from_params
        return params[:member_id].to_i if params[:member_id].present?

        nil
      end

      def invite_payload
        payload = {
          'email' => params[:email].to_s,
          'first_name' => params[:first_name].to_s,
          'last_name' => params[:last_name].to_s
        }
        payload['role'] = params[:role].to_i if params[:role].present?
        payload
      end
    end
  end
end
