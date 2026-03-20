# frozen_string_literal: true

module Api
  module V1
    class DataSourcesController < Api::BaseController
      def index
        execute_tool(action_type: 'datasource.list', payload: {})
      end

      def validate_connection
        execute_tool(
          action_type: 'datasource.validate_connection',
          payload: connection_payload
        )
      end

      def create
        execute_tool(
          action_type: 'datasource.create',
          payload: create_payload
        )
      end

      private

      def connection_payload
        {
          'host' => params[:host].to_s,
          'port' => normalized_port,
          'database_name' => params[:database_name].to_s,
          'username' => params[:username].to_s,
          'password' => params[:password].to_s,
          'ssl_mode' => params[:ssl_mode].to_s.presence,
          'extract_category_values' => boolean_param(:extract_category_values)
        }.compact
      end

      def create_payload
        connection_payload.merge(
          'name' => params[:name].to_s,
          'selected_tables' => Array(params[:selected_tables]).flatten.compact.map(&:to_s)
        )
      end

      def normalized_port
        port = params[:port]
        return nil if port.blank?
        return port if port.is_a?(Integer)
        return port.to_i if port.to_s.match?(/\A\d+\z/)

        port
      end

      def boolean_param(name)
        value = params[name]
        return value if value.in?([true, false])
        return ActiveModel::Type::Boolean.new.cast(value) if value.present?

        nil
      end
    end
  end
end
