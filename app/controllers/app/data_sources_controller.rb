# frozen_string_literal: true

module App
  class DataSourcesController < ApplicationController
    before_action :require_authentication!

    def index
      @data_sources = current_user.data_sources
      redirect_to new_app_data_source_path if @data_sources.empty?
    end

    def show
      @data_source = data_source
    end

    def new; end

    def create
      return redirect_to app_data_sources_path unless create_params[:url]

      data_source = DataSource.new(url: create_params[:url], user: current_user)

      return handle_invalid_data_source_create(data_source) unless data_source.save

      redirect_to set_up_app_data_source_path(data_source)
    end

    def set_up
      @data_source = data_source
    end

    private

    def data_source
      @data_source ||= DataSource.find(params[:id])
    end

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
