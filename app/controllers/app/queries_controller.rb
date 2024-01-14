# frozen_string_literal: true

module App
  class QueriesController < ApplicationController
    before_action :require_authentication!

    def index; end
  end
end
