# frozen_string_literal: true

module Api
  module V1
    class WorkspacesController < Api::BaseController
      def update
        execute_tool(
          action_type: 'workspace.update_name',
          payload: {
            'name' => params[:name].to_s
          }
        )
      end

      def destroy
        execute_tool(action_type: 'workspace.delete', payload: {})
      end
    end
  end
end
