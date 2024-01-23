# frozen_string_literal: true

module App
  module Workspaces
    class DataSourcesController < ApplicationController
      before_action :require_authentication!

      def index
        @data_sources = data_sources
        @data_sources_stats = DataSourcesStatsService.new(data_sources:)

        redirect_to new_app_workspace_data_source_path(workspace) if data_sources.empty?
      end

      def show
        @data_source = data_source
        @data_sources_stats = DataSourcesStatsService.new(data_sources: [data_source])
      end

      def new
        @workspace = workspace
      end

      def create
        return redirect_to app_workspace_data_sources_path(workspace) unless data_source_params[:url]

        data_source = DataSource.new(url: data_source_params[:url], workspace:)

        return handle_invalid_data_source_create(data_source) unless data_source.save

        redirect_to app_workspace_data_source_set_up_index_path(workspace, data_source)
      end

      def update
        if data_source_params[:url]
          data_source.url = data_source_params[:url]
          data_source.verified_at = nil
          return handle_invalid_data_source_update(data_source) unless data_source.save
        end

        redirect_to app_workspace_data_source_path(workspace, data_source)
      end

      def destroy
        data_source.destroy!

        redirect_to app_workspace_data_sources_path(workspace)
      end

      private

      def workspaces
        @workspaces ||= current_user.workspaces
      end

      def workspace
        @workspace ||= workspaces.find(params[:workspace_id])
      end

      def data_sources
        @data_sources ||= workspace.data_sources
      end

      def data_source
        @data_source ||= workspace.data_sources.find(params[:id])
      end

      def data_source_params
        params.permit(
          :url,
          :commit,
          :authenticity_token,
          :action
        )
      end

      def handle_invalid_data_source_create(data_source)
        flash.alert = data_source.errors.full_messages.first
        redirect_to app_workspace_data_sources_path(workspace)
      end

      def handle_invalid_data_source_update(data_source)
        flash.alert = data_source.errors.full_messages.first
        redirect_to app_workspace_data_source_path(workspace, data_source)
      end
    end
  end
end
