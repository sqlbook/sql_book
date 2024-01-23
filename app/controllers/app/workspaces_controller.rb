# frozen_string_literal: true

module App
  class WorkspacesController < ApplicationController
    before_action :require_authentication!

    def index
      @workspaces = workspaces
    end

    def new
      # TODO
    end

    private

    def workspaces
      @workspaces ||= current_user.workspaces
    end
  end
end
