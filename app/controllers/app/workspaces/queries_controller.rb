# frozen_string_literal: true

module App
  module Workspaces
    class QueriesController < ApplicationController
      before_action :require_authentication!

      def index
        @queries = queries
        @data_sources = data_sources

        return unless data_sources.empty?
        return unless can_manage_data_sources?(workspace:)

        redirect_to new_app_workspace_data_source_path(workspace)
      end

      private

      def workspaces
        @workspaces ||= current_user.workspaces
      end

      def workspace
        @workspace ||= find_workspace_for_current_user!(param_key: :workspace_id)
      end

      def data_sources
        @data_sources ||= workspace.data_sources
      end

      def queries
        data_source_id = data_sources.select(:id)
        queries = Query.where(data_source_id:, saved: true)
        queries = queries.where('LOWER(name) LIKE ?', "%#{params[:search].downcase}%") if params[:search]
        queries
      end
    end
  end
end
