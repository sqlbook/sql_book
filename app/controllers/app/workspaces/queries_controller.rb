# frozen_string_literal: true

module App
  module Workspaces
    class QueriesController < ApplicationController
      before_action :require_authentication!
      before_action :set_workspace
      before_action :authorize_query_write_access!, only: :destroy_group

      attr_reader :workspace

      def index
        @queries = queries
        @data_sources = data_sources
        @visible_columns = current_user.query_library_visible_columns
        @view_mode = view_mode
        @group_rows = grouped_query_rows if @view_mode == 'groups'

        return unless data_sources.empty?
        return unless can_manage_data_sources?(workspace:)

        redirect_to new_app_workspace_data_source_path(workspace)
      end

      def update_visible_columns
        current_user.update_query_library_visible_columns!(columns: visible_columns_params)

        respond_to do |format|
          format.json { render json: { visible_columns: current_user.query_library_visible_columns } }
          format.html { redirect_to app_workspace_queries_path(workspace, search: params[:search]) }
        end
      end

      def destroy_group
        group = workspace.query_groups.find(params[:group_id])
        group.destroy!

        redirect_to app_workspace_queries_path(workspace, search: params[:search], view: 'groups')
      end

      private

      def workspaces
        @workspaces ||= current_user.workspaces
      end

      def set_workspace
        @workspace = find_workspace_for_current_user!(param_key: :workspace_id)
      end

      def data_sources
        @data_sources ||= workspace.data_sources
      end

      def queries
        data_source_id = data_sources.select(:id)
        lower_name = Arel::Nodes::NamedFunction.new('LOWER', [Query.arel_table[:name]])
        queries = Query.includes(:data_source, :author, :last_updated_by, :query_groups)
          .where(data_source_id:, saved: true)
        queries = queries.where('LOWER(name) LIKE ?', "%#{params[:search].downcase}%") if params[:search]
        queries.order(lower_name.asc, :id)
      end

      def visible_columns_params
        params.fetch(:visible_columns, [])
      end

      def view_mode
        params[:view].to_s == 'groups' ? 'groups' : 'all'
      end

      def grouped_query_rows
        workspace.query_groups.alphabetical.map do |group|
          matching_queries = grouped_queries[group]
          {
            group:,
            open: params[:search].present? && matching_queries.present?,
            queries: matching_queries.sort_by { |query| [query.name.to_s.downcase, query.id] }
          }
        end
      end

      def grouped_queries
        @grouped_queries ||= @queries.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |query, hash|
          query.query_groups.each { |group| hash[group] << query }
        end
      end

      def authorize_query_write_access!
        return if can_write_queries?(workspace:)

        deny_workspace_access!(workspace:)
      end
    end
  end
end
