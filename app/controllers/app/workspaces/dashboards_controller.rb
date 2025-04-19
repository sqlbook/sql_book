# frozen_string_literal: true

module App
  module Workspaces
    class DashboardsController < ApplicationController
      before_action :require_authentication!

      def index
        @workspace = workspace
        @data_sources = data_sources
        @dashboards = dashboards

        redirect_to new_app_workspace_data_source_path(workspace) if data_sources.empty?
      end

      def show
        @workspace = workspace
        @dashboard = dashboard
      end

      def new
        @workspace = workspace
      end

      def create
        return redirect_to new_app_workspace_dashboard_path(workspace) unless dashboard_params[:name]

        dashboard = Dashboard.create!(name: dashboard_params[:name], workspace:, author: current_user)

        redirect_to app_workspace_dashboard_path(workspace, dashboard)
      end

      def destroy
        dashboard.destroy!
        redirect_to app_workspace_dashboards_path
      end

      private

      def workspace
        @workspace ||= current_user.workspaces.find(params[:workspace_id])
      end

      def data_sources
        @data_sources ||= workspace.data_sources
      end

      def dashboards
        dashboards = workspace.dashboards
        dashboards = dashboards.where('LOWER(name) LIKE ?', "%#{params[:search].downcase}%") if params[:search]
        dashboards
      end

      def dashboard
        @dashboard ||= dashboards.find(params[:id])
      end

      def dashboard_params
        params.require(%i[name])
      end
    end
  end
end
