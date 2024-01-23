# frozen_string_literal: true

module App
  module Workspaces
    class DashboardsController < ApplicationController
      before_action :require_authentication!

      def index
        @workspace = workspace
        @data_sources = data_sources
      end

      private

      def workspace
        @workspace ||= current_user.workspaces.find(params[:workspace_id])
      end

      def data_sources
        @data_sources ||= workspace.data_sources
      end
    end
  end
end
