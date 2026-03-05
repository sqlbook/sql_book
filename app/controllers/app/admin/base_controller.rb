# frozen_string_literal: true

module App
  module Admin
    class BaseController < ApplicationController
      before_action :require_authentication!
      before_action :require_super_admin!
      before_action :set_admin_navigation!

      private

      def require_super_admin!
        return if current_user&.super_admin?

        deny_admin_access!
      end

      def set_admin_navigation!
        @admin_navigation_items = [
          {
            key: :dashboard,
            path: app_admin_dashboard_path,
            icon: 'ri-line-chart-line',
            label: 'Dashboard',
            aria_label: 'Open admin dashboard'
          },
          {
            key: :workspaces,
            path: app_admin_workspaces_path,
            icon: 'ri-briefcase-4-line',
            label: 'Workspaces',
            aria_label: 'Open admin workspaces'
          },
          {
            key: :users,
            path: app_admin_users_path,
            icon: 'ri-user-3-line',
            label: 'Users',
            aria_label: 'Open admin users'
          },
          {
            key: :translations,
            path: app_admin_translations_path,
            icon: 'ri-translate-2',
            label: 'Translations',
            aria_label: 'Open admin translations'
          }
        ]

        @admin_nav_section = controller_name.to_sym
      end
    end
  end
end
