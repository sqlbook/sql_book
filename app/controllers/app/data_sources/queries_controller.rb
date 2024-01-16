# frozen_string_literal: true

module App
  module DataSources
    class QueriesController < ApplicationController
      before_action :require_authentication!

      def index
        @data_sources = current_user.data_sources
        @data_source = data_source
      end

      def show
        @data_sources = current_user.data_sources
        @query = query
      end

      def create
        query = Query.create(query: query_params[:query], data_source:)
        redirect_to app_data_source_query_path(data_source, query)
      end

      def update
        query.update!(**update_params, saved: update_params[:name].present?)

        redirect_to app_data_source_query_path(data_source, query, tab: 'settings')
      end

      private

      def data_source
        @data_source ||= current_user.data_sources.find(params[:data_source_id])
      end

      def query
        Query.find_by!(id: params[:id], data_source_id: data_source.id)
      end

      def update_params
        query_params.slice(:name, :query)
      end

      def query_params
        params.permit(
          :data_source_id,
          :query,
          :name,
          :action,
          :authenticity_token
        )
      end
    end
  end
end
