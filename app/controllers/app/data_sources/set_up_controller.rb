# frozen_string_literal: true

module App
  module DataSources
    class SetUpController < ApplicationController
      before_action :require_authentication!

      def index
        redirect_to app_data_sources_path if data_source.verified?
      end

      private

      def data_source
        @data_source ||= current_user.data_sources.find(params[:data_source_id])
      end
    end
  end
end
