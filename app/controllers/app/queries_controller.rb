# frozen_string_literal: true

module App
  class QueriesController < ApplicationController
    before_action :require_authentication!

    def index
      @queries = queries
      @data_sources = data_sources
    end

    private

    def queries
      data_source_id = data_sources.select(:data_source_id)
      queries = Query.where(data_source_id:, saved: true)
      queries = queries.where('LOWER(name) LIKE ?', "%#{params[:search].downcase}%") if params[:search]
      queries
    end

    def data_sources
      @data_sources ||= current_user.data_sources
    end
  end
end
