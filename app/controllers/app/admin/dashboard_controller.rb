# frozen_string_literal: true

module App
  module Admin
    class DashboardController < BaseController
      def index
        @dashboard_metrics = build_metrics
        @role_breakdown = Member.accepted.group(:role).count
      end

      private

      def build_metrics
        total_workspaces = Workspace.count
        total_data_sources = DataSource.count

        {
          total_users: User.count,
          new_users_last_30_days: User.where(created_at: 30.days.ago..).count,
          total_workspaces:,
          total_data_sources:,
          total_dashboards: Dashboard.count,
          total_queries: Query.count,
          avg_users_per_workspace: ratio(Member.accepted.count, total_workspaces),
          avg_data_sources_per_workspace: ratio(total_data_sources, total_workspaces)
        }
      end

      def ratio(numerator, denominator)
        return 0 if denominator.zero?

        (numerator.to_f / denominator).round(2)
      end
    end
  end
end
