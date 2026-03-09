# frozen_string_literal: true

module Dev
  class ApiDocsController < ApplicationController
    def show; end

    def openapi
      spec_path = Rails.root.join('config/openapi/v1.json')
      render json: JSON.parse(spec_path.read)
    end
  end
end
