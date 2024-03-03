# frozen_string_literal: true

module App
  module WorkspacesHelper
    include ActiveSupport::NumberHelper

    def current_user_role(workspace:, current_user:)
      workspace.role_for(user: current_user)
    end
  end
end
