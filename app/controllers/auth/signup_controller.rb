# frozen_string_literal: true

module Auth
  class SignupController < ApplicationController
    def index; end

    def new
      return redirect_to auth_signup_index_path unless email

      if User.exists?(email:)
        flash.alert = I18n.t('auth.account_already_exists')
        return redirect_to auth_signup_index_path
      end

      one_time_password_service.create!
    end

    def create
      return redirect_to auth_signup_index_path unless email
      return redirect_to auth_signup_index_path unless token

      return create_and_authenticate_user! if one_time_password_service.verify(token:)

      handle_invalid_signup_code
    end

    def resend
      return redirect_to auth_signup_index_path unless email

      one_time_password_service.resend!
      redirect_to new_auth_signup_path(email:)
    end

    private

    def handle_invalid_signup_code
      flash.alert = I18n.t('auth.invalid_signup_code', link: resend_auth_signup_index_path(email:))
      redirect_to new_auth_signup_path(email:)
    end

    def create_and_authenticate_user!
      user = User.create!(
        email:,
        first_name: signup_params[:first_name],
        last_name: signup_params[:last_name]
      )
      session[:current_user_id] = user.id
      redirect_to new_app_workspace_path
    end

    def signup_params # rubocop:disable Metrics/MethodLength
      params.permit(
        :email,
        :first_name,
        :last_name,
        :accept_terms,
        :one_time_password_1,
        :one_time_password_2,
        :one_time_password_3,
        :one_time_password_4,
        :one_time_password_5,
        :one_time_password_6
      )
    end

    def email
      signup_params[:email]
    end

    def token
      6.times.map { |i| signup_params[:"one_time_password_#{i + 1}"] }.join.presence
    end

    def one_time_password_service
      @one_time_password_service ||= OneTimePasswordService.new(email:, auth_type: :signup)
    end
  end
end
