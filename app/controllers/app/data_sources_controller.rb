# frozen_string_literal: true

module App
  class DataSourcesController < ApplicationController
    before_action :require_authentication!

    def index
      @data_sources = data_sources
      @data_sources_stats = DataSourcesStatsService.new(data_sources:)

      redirect_to new_app_data_source_path if data_sources.empty?
    end

    def show
      @data_source = data_source
      @data_sources_stats = DataSourcesStatsService.new(data_sources: [data_source])
    end

    def new; end

    def create
      return redirect_to app_data_sources_path unless data_source_params[:url]

      data_source = DataSource.new(url: data_source_params[:url], user: current_user)

      return handle_invalid_data_source_create(data_source) unless data_source.save

      data_source.create_views!

      redirect_to app_data_source_set_up_index_path(data_source)
    end

    def update
      if data_source_params[:url]
        data_source.url = data_source_params[:url]
        data_source.verified_at = nil
        return handle_invalid_data_source_update(data_source) unless data_source.save
      end

      redirect_to app_data_source_path(data_source)
    end

    def destroy
      EventDeleteJob.perform_later(data_source.external_uuid)
      DataSourcesViewService.new(data_source:).destroy!

      data_source.destroy!

      redirect_to app_data_sources_path
    end

    private

    def data_source
      @data_source ||= data_sources.find(params[:id])
    end

    def data_sources
      @data_sources ||= current_user.data_sources
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
      redirect_to app_data_sources_path
    end

    def handle_invalid_data_source_update(data_source)
      flash.alert = data_source.errors.full_messages.first
      redirect_to app_data_source_path(data_source)
    end
  end
end
