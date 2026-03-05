# frozen_string_literal: true

module App
  module Admin
    class UsersController < BaseController
      before_action :load_users

      def index
        selected_user_id = params[:user_id].to_s.presence
        @selected_user = selected_user_id.present? ? user_for_panel(selected_user_id:) : nil
      end

      private

      def load_users
        scope = User.includes(members: :workspace).order(created_at: :desc)
        @users = search_query.present? ? scope.where(user_search_query, query: "%#{search_query}%") : scope
      end

      def user_search_query
        <<~SQL.squish
          LOWER(users.first_name) LIKE :query
          OR LOWER(users.last_name) LIKE :query
          OR LOWER(users.email) LIKE :query
        SQL
      end

      def search_query
        @search_query ||= params[:q].to_s.strip.downcase.presence
      end

      def user_for_panel(selected_user_id:)
        @users.find { |user| user.id == selected_user_id.to_i } ||
          User.includes(members: :workspace).find_by(id: selected_user_id)
      end
    end
  end
end
