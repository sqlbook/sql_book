# frozen_string_literal: true

module App
  class QueriesController < ApplicationController
    before_action :require_authentication!

    def index
      @queries = queries
    end

    private

    def queries
      queries = current_user.queries.where(saved: true)
      queries = queries.where('LOWER(name) LIKE ?', "%#{params[:search].downcase}%") if params[:search]
      queries
    end
  end
end
