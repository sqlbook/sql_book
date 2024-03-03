# frozen_string_literal: true

module App
  class WorkspacesController < ApplicationController
    before_action :require_authentication!

    def index
      @workspaces = workspaces
      @workspaces_stats = WorkspacesStatsService.new(workspaces:)

      redirect_to new_app_workspace_path if workspaces.empty?
    end

    def show
      @workspace = workspace
      @workspaces_stats = WorkspacesStatsService.new(workspaces: [workspace])
    end

    def new; end

    def create
      return redirect_to new_app_workspace_path unless workspace_params[:name]

      workspace = create_workspace!
      create_owner!(workspace:)

      # This is their only workspace so they should create a datasource
      return redirect_to new_app_workspace_data_source_path(workspace) if current_user.workspaces.size == 1

      redirect_to app_workspaces_path
    end

    private

    def workspaces
      @workspaces ||= current_user.workspaces
    end

    def workspace
      @workspace ||= workspaces.find(params[:id])
    end

    def workspace_params
      params.permit(:name)
    end

    def create_workspace!
      Workspace.create!(name: workspace_params[:name])
    end

    def create_owner!(workspace:)
      Member.create!(user: current_user, workspace:, role: Member::Roles::OWNER)
    end
  end
end
