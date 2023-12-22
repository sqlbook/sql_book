# frozen_string_literal: true

module App
  class DataSourcesController < ApplicationController
    before_action :require_authentication!

    def new; end

    def create
      return redirect_to app_data_sources_path unless create_params[:url]

      data_source = DataSource.new(url: create_params[:url], user: current_user)

      return handle_invalid_data_source_create(data_source) unless data_source.save

      redirect_to app_dashboard_index_path
    end

    private

    def create_params
      params.permit(
        :url,
        :commit,
        :authenticity_token,
        :action
      )
    end

    def handle_invalid_data_source_create(data_source)
      flash.alert = data_source.errors.full_messages.first
      redirect_to app_data_sources_path
    end
  end
end
