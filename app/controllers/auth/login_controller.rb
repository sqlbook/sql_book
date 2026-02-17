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

      one_time_password_service.create!
    rescue OneTimePasswordService::DeliveryError
      flash.alert = I18n.t('auth.unable_to_send_code')
      redirect_to auth_login_index_path
    end

    def create
      return redirect_to auth_login_index_path unless email
      return redirect_to auth_login_index_path unless token

      return find_and_authenticate_user! if one_time_password_service.verify(token:)

      handle_invalid_login_code
    end

    def resend
      return redirect_to auth_login_index_path unless email

      one_time_password_service.resend!
      redirect_to new_auth_login_path(email:)
    rescue OneTimePasswordService::DeliveryError
      flash.alert = I18n.t('auth.unable_to_send_code')
      redirect_to auth_login_index_path
    end

    private

    def find_and_authenticate_user!
      user = User.find_by!(email:)
      reset_session
      session[:current_user_id] = user.id
      redirect_to app_workspaces_path
    end

    def handle_invalid_login_code
      flash.alert = I18n.t('auth.invalid_login_code', link: resend_auth_login_index_path(email:))
      redirect_to new_auth_login_path(email:)
    end

    def login_params
      params.permit(
        :email,
        :one_time_password_1,
        :one_time_password_2,
        :one_time_password_3,
        :one_time_password_4,
        :one_time_password_5,
        :one_time_password_6
      )
    end

    def email
      login_params[:email]
    end

    def token
      6.times.map { |i| login_params[:"one_time_password_#{i + 1}"] }.join.presence
    end

    def one_time_password_service
      @one_time_password_service ||= OneTimePasswordService.new(email:, auth_type: :login)
    end
  end
end
