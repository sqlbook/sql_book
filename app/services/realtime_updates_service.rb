# frozen_string_literal: true

class RealtimeUpdatesService
  class << self
    def workspace_members_stream(workspace:)
      [:workspace_members, workspace.id]
    end

    def user_app_stream(user:)
      [:user_app, user.id]
    end

    def refresh_workspace_members(workspace:)
      Turbo::StreamsChannel.broadcast_refresh_to(workspace_members_stream(workspace:))
    end

    def refresh_user_app(user:)
      Turbo::StreamsChannel.broadcast_refresh_to(user_app_stream(user:))
    end

    def refresh_users_app(users:)
      Array(users).compact.uniq.each { |user| refresh_user_app(user:) }
    end
  end
end
