# frozen_string_literal: true

module App
  module Workspaces
    module DataSources
      class SetUpController < ApplicationController
        before_action :require_authentication!

        def index
          redirect_to app_workspace_data_sources_path(workspace) if data_source.verified?
        end

        private

        def workspace
          @workspace ||= current_user.workspaces.find(params[:workspace_id])
        end

        def data_source
          @data_source ||= workspace.data_sources.find(params[:data_source_id])
        end
      end
    end
  end
end
