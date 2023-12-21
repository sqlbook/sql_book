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

      one_time_token_service.create!
    end

    def create
      return redirect_to auth_signup_index_path unless email
      return redirect_to auth_signup_index_path unless token

      return create_and_authenticate_user! if one_time_token_service.verify(token:)

      flash.alert = I18n.t('auth.invalid_signup_code')
      redirect_to new_auth_signup_path(email:)
    end

    private

    def create_and_authenticate_user!
      user = User.create!(email:)
      session[:current_user_id] = user.id
      redirect_to app_dashboard_index_path
    end

    def signup_params # rubocop:disable Metrics/MethodLength
      params.permit(
        :email,
        :accept_terms,
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
      signup_params[:email]
    end

    def token
      6.times.map { |i| signup_params[:"one_time_token_#{i + 1}"] }.join.presence
    end

    def one_time_token_service
      @one_time_token_service ||= OneTimeTokenService.new(email:, auth_type: :signup)
    end
  end
end
