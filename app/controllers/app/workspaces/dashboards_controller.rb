# frozen_string_literal: true

module App
  module Workspaces
    class DashboardsController < ApplicationController
      before_action :require_authentication!

      def index
        @workspace = workspace
        @data_sources = data_sources

        redirect_to new_app_workspace_data_source_path(workspace) if data_sources.empty?
      end

      private

      def workspace
        @workspace ||= current_user.workspaces.find(params[:workspace_id])
      end

      def data_sources
        @data_sources ||= workspace.data_sources
      end
    end
  end
end
