# frozen_string_literal: true

module App
  module Admin
    class BaseController < ApplicationController
      before_action :require_authentication!
      before_action :require_super_admin!

      private

      def require_super_admin!
        return if current_user&.super_admin?

        deny_admin_access!
      end
    end
  end
end
