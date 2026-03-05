# frozen_string_literal: true

module App
  module Admin
    class WorkspacesController < BaseController
      before_action :load_workspaces

      def index
        selected_workspace_id = params[:workspace_id].to_s.presence
        @selected_workspace = selected_workspace_id.present? ? workspace_for_panel(selected_workspace_id:) : nil
      end

      private

      def load_workspaces
        scope = Workspace.includes(:dashboards, { members: :user }, { data_sources: :queries }).order(created_at: :desc)
        @workspaces = search_query.present? ? scope.where('LOWER(workspaces.name) LIKE ?', "%#{search_query}%") : scope
      end

      def search_query
        @search_query ||= params[:q].to_s.strip.downcase.presence
      end

      def workspace_for_panel(selected_workspace_id:)
        @workspaces.find { |workspace| workspace.id == selected_workspace_id.to_i } ||
          Workspace.includes(:dashboards, { members: :user }, { data_sources: :queries })
            .find_by(id: selected_workspace_id)
      end
    end
  end
end
