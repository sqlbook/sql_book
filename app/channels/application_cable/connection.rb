# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_visitor

    def connect
      if tracking_request?
        self.current_visitor = find_authorized_visitor
      else
        self.current_user = find_authorized_user
      end
    end

    private

    def tracking_request?
      request.path == '/events/in' || request.params[:data_source_uuid].present?
    end

    def find_authorized_user
      user = User.find_by(id: request.session[:current_user_id])
      return user if user

      reject_unauthorized_connection
    end

    def find_authorized_visitor
      data_source = DataSource.find_by(external_uuid: data_source_uuid)

      reject_unauthorized_connection unless data_source
      reject_unauthorized_connection unless origin_valid?(data_source)

      "#{data_source_uuid}::#{visitor_uuid}::#{session_uuid}"
    rescue KeyError
      Rails.logger.warn 'Visitor did not have a valid payload'
      reject_unauthorized_connection
    end

    def origin_valid?(data_source)
      data_source.url.sub('www.', '') == request.origin.sub('www.', '')
    end

    def data_source_uuid
      request.params.fetch(:data_source_uuid)
    end

    def visitor_uuid
      request.params.fetch(:visitor_uuid)
    end

    def session_uuid
      request.params.fetch(:session_uuid)
    end
  end
end
