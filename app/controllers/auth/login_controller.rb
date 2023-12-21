# frozen_string_literal: true

module Auth
  class LoginController < ApplicationController
    def index; end

    def new
      return redirect_to auth_login_index_path unless email

      unless User.exists?(email:)
        flash.alert = I18n.t('auth.account_does_not_exist')
        return redirect_to auth_login_index_path
      end

      one_time_token_service.create!
    end

    def create
      return redirect_to auth_login_index_path unless email
      return redirect_to auth_login_index_path unless token

      return find_and_authenticate_user! if one_time_token_service.verify(token:)

      flash.alert = I18n.t('auth.invalid_login_code')
      redirect_to new_auth_login_path(email:)
    end

    private

    def find_and_authenticate_user!
      user = User.find_by!(email:)
      session[:current_user_id] = user.id
      redirect_to app_dashboard_index_path
    end

    def login_params # rubocop:disable Metrics/MethodLength
      params.permit(
        :email,
        :one_time_token_1,
        :one_time_token_2,
        :one_time_token_3,
        :one_time_token_4,
        :one_time_token_5,
        :one_time_token_6,
        :commit,
        :authenticity_token
      )
    end

    def email
      login_params[:email]
    end

    def token
      6.times.map { |i| login_params[:"one_time_token_#{i + 1}"] }.join.presence
    end

    def one_time_token_service
      @one_time_token_service ||= OneTimeTokenService.new(email:, auth_type: :login)
    end
  end
end
