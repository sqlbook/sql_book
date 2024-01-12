# frozen_string_literal: true

module App
  module DataSources
    class QueriesController < ApplicationController
      before_action :require_authentication!

      def index
        @data_sources = current_user.data_sources
        @data_source = data_source
      end

      def show; end

      def create
        redirect_to app_data_source_queries_path(data_source)
      end

      def update; end

      private

      def data_source
        @data_source ||= current_user.data_sources.find(params[:data_source_id])
      end

      def query_params
        params.permit(
          :data_source_id,
          :query,
          :action,
          :authenticity_token
        )
      end
    end
  end
end
