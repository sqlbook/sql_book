# frozen_string_literal: true

module Auth
  class SignupController < ApplicationController
    def index; end

    def new
      return redirect_to auth_signup_index_path unless email
      return handle_terms_not_accepted unless accepted_terms?
      return handle_existing_account if User.exists?(email:)

      send_signup_code!
    end

    def create
      return redirect_to auth_signup_index_path unless create_params_present?
      return handle_terms_not_accepted unless accepted_terms?
      return create_and_authenticate_user! if one_time_password_service.verify(token:)

      handle_invalid_signup_code
    end

    def resend
      return redirect_to auth_signup_index_path unless email

      one_time_password_service.resend!
      redirect_to new_auth_signup_path(signup_redirect_params)
    rescue OneTimePasswordService::DeliveryError
      flash.alert = I18n.t('auth.unable_to_send_code')
      redirect_to auth_signup_index_path
    end

    private

    def send_signup_code!
      one_time_password_service.create!
    rescue OneTimePasswordService::DeliveryError
      flash.alert = I18n.t('auth.unable_to_send_code')
      redirect_to auth_signup_index_path
    end

    def handle_invalid_signup_code
      flash.alert = I18n.t('auth.invalid_signup_code', link: resend_auth_signup_index_path(signup_redirect_params))
      redirect_to new_auth_signup_path(signup_redirect_params)
    end

    def handle_existing_account
      flash.alert = I18n.t('auth.account_already_exists')
      redirect_to auth_signup_index_path
    end

    def handle_terms_not_accepted
      flash.alert = I18n.t('auth.must_accept_terms')
      redirect_to auth_signup_index_path
    end

    def create_and_authenticate_user!
      user = User.create!(
        email:,
        first_name: signup_params[:first_name],
        last_name: signup_params[:last_name],
        terms_accepted_at: Time.current,
        terms_version: User::CURRENT_TERMS_VERSION
      )
      reset_session
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

    def first_name
      signup_params[:first_name]
    end

    def last_name
      signup_params[:last_name]
    end

    def email
      signup_params[:email]
    end

    def token
      6.times.map { |i| signup_params[:"one_time_password_#{i + 1}"] }.join.presence
    end

    def accepted_terms?
      ActiveModel::Type::Boolean.new.cast(signup_params[:accept_terms])
    end

    def one_time_password_service
      @one_time_password_service ||= OneTimePasswordService.new(
        email:,
        auth_type: :signup,
        magic_link_params: signup_redirect_params.except(:email, :accept_terms)
      )
    end

    def signup_redirect_params
      {
        email:,
        first_name:,
        last_name:,
        accept_terms: '1'
      }.compact
    end

    def create_params_present?
      [email, token, first_name, last_name].all?
    end
  end
end
