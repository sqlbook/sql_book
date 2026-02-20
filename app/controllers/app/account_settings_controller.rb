# frozen_string_literal: true

module App
  class AccountSettingsController < ApplicationController
    before_action :require_authentication!, except: %i[verify_email]

    def show
      @account_user = current_user
    end

    def update
      requested_email = requested_email_change

      if email_change_taken?(requested_email:)
        return redirect_with_toast(
          path: app_account_settings_path,
          toast: toast(type: 'error', key: 'email_unavailable')
        )
      end

      persist_account_changes!(requested_email:)
      redirect_with_toast(path: app_account_settings_path, toast: update_success_toast(requested_email:))
    rescue StandardError => e
      Rails.logger.error("Account settings update failed: #{e.class} #{e.message}")
      redirect_with_toast(path: app_account_settings_path, toast: toast(type: 'error', key: 'update_failed'))
    end

    def verify_email
      user = User.find_by(email_change_verification_token: params[:token].to_s)
      return redirect_with_toast(path: auth_login_index_path, toast: toast(type: 'error', key: 'email_verification_expired')) unless user # rubocop:disable Layout/LineLength

      authenticate_user!(user:)
      return complete_email_verification! if user.confirm_email_change!(token: params[:token].to_s)

      expire_email_verification!(user:)
    end

    private

    def account_settings_params
      params.permit(:first_name, :last_name, :email)
    end

    def requested_email_change
      submitted_email = account_settings_params[:email].to_s.strip.downcase
      return nil if submitted_email.blank? || submitted_email == current_user.email

      submitted_email
    end

    def email_taken?(email:)
      User.where.not(id: current_user.id).exists?(email:)
    end

    def email_change_taken?(requested_email:)
      requested_email.present? && email_taken?(email: requested_email)
    end

    def update_profile_names!
      current_user.update!(
        first_name: account_settings_params[:first_name],
        last_name: account_settings_params[:last_name]
      )
    end

    def queue_email_change_verification!(requested_email:)
      return unless requested_email

      User.transaction do
        current_user.begin_email_change_verification!(new_email: requested_email)
        AccountMailer.verify_email_change(
          user: current_user,
          token: current_user.email_change_verification_token
        ).deliver_now
      end
    end

    def persist_account_changes!(requested_email:)
      update_profile_names!
      queue_email_change_verification!(requested_email:)
    end

    def update_success_toast(requested_email:)
      return toast(type: 'success', key: 'updated') unless requested_email

      toast(type: 'information', key: 'email_verification_pending')
    end

    def complete_email_verification!
      redirect_with_toast(path: app_workspaces_path, toast: toast(type: 'success', key: 'email_verified'))
    end

    def expire_email_verification!(user:)
      user.clear_email_change_verification!
      redirect_with_toast(
        path: app_account_settings_path,
        toast: toast(type: 'error', key: 'email_verification_expired')
      )
    end

    def authenticate_user!(user:)
      reset_session
      session[:current_user_id] = user.id
    end

    def toast(type:, key:)
      {
        type:,
        title: I18n.t("toasts.account_settings.#{key}.title"),
        body: I18n.t("toasts.account_settings.#{key}.body")
      }
    end

    def redirect_with_toast(path:, toast:)
      flash[:toast] = toast
      redirect_to path
    end
  end
end
