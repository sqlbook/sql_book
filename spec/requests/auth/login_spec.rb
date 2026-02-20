# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth::Logins', type: :request do
  describe 'GET /auth/login' do
    it 'renders a form to enter an email' do
      get '/auth/login'

      expect(response.body).to include('type="email" name="email"')
    end
  end

  describe 'authenticated user redirects' do
    let(:user) { create(:user) }

    before { sign_in(user) }

    it 'redirects /auth/login to app workspaces' do
      get '/auth/login'

      expect(response).to redirect_to(app_workspaces_path)
    end

    it 'redirects /auth/login/new to app workspaces' do
      get '/auth/login/new', params: { email: user.email }

      expect(response).to redirect_to(app_workspaces_path)
    end

    it 'redirects /auth/login/resend to app workspaces' do
      get '/auth/login/resend', params: { email: user.email }

      expect(response).to redirect_to(app_workspaces_path)
    end

    it 'redirects /auth/login/magic_link to app workspaces' do
      get '/auth/login/magic_link'

      expect(response).to redirect_to(app_workspaces_path)
    end
  end

  describe 'GET /auth/login/new' do
    context 'when there is no email submitted' do
      it 'redirects back to the index page' do
        get '/auth/login/new'

        expect(response).to redirect_to(auth_login_index_path)
      end
    end

    context 'when there is no account for this email' do
      let(:email) { "#{SecureRandom.base36}@email.com" }

      it 'redirects back to the index page' do
        get '/auth/login/new', params: { email: }

        expect(response).to redirect_to(auth_login_index_path)
      end

      it 'displays a flash message' do
        get '/auth/login/new', params: { email: }

        expect(flash[:alert]).to eq('An account with this email does not exist')
      end
    end

    context 'when there is an account for this email' do
      let(:user) { create(:user) }
      let(:one_time_password_service) { instance_double(OneTimePasswordService, create!: nil) }

      before do
        allow(OneTimePasswordService).to receive(:new).and_return(one_time_password_service)
      end

      it 'creates a one time token' do
        get '/auth/login/new', params: { email: user.email }

        expect(one_time_password_service).to have_received(:create!)
      end

      it 'renders the one time token inputs' do
        get '/auth/login/new', params: { email: user.email }

        expect(response.body).to include('type="text" name="one_time_password_1"')
        expect(response.body).to include('type="text" name="one_time_password_2"')
        expect(response.body).to include('type="text" name="one_time_password_3"')
        expect(response.body).to include('type="text" name="one_time_password_4"')
        expect(response.body).to include('type="text" name="one_time_password_5"')
        expect(response.body).to include('type="text" name="one_time_password_6"')
      end
    end

    context 'when otp delivery fails' do
      let(:user) { create(:user) }
      let(:one_time_password_service) { instance_double(OneTimePasswordService) }

      before do
        allow(OneTimePasswordService).to receive(:new).and_return(one_time_password_service)
        allow(one_time_password_service).to receive(:create!).and_raise(OneTimePasswordService::DeliveryError, 'failed')
      end

      it 'redirects back to the index page' do
        get '/auth/login/new', params: { email: user.email }

        expect(response).to redirect_to(auth_login_index_path)
      end

      it 'displays a flash message' do
        get '/auth/login/new', params: { email: user.email }

        expect(flash[:alert]).to eq(I18n.t('auth.unable_to_send_code'))
      end
    end
  end

  describe 'GET /auth/login/resend' do
    context 'when there is no email provided' do
      it 'redirects back to the index page' do
        get '/auth/login/resend'

        expect(response).to redirect_to(auth_login_index_path)
      end
    end

    context 'when there is an email provided' do
      let(:email) { "#{SecureRandom.base36}@email.com" }

      before do
        create(:one_time_password, email:)
      end

      it 'redirects to the new auth page' do
        get '/auth/login/resend', params: { email: }
        expect(response).to redirect_to(new_auth_login_path(email:))
      end
    end
  end

  describe 'POST /auth/login' do
    context 'when there is no email submitted' do
      it 'redirects back to the index page' do
        post '/auth/login'

        expect(response).to redirect_to(auth_login_index_path)
      end
    end

    context 'when there is an email, but no token submitted' do
      let(:email) { "#{SecureRandom.base36}@email.com" }

      it 'redirects back to the index page' do
        post '/auth/login', params: { email: }

        expect(response).to redirect_to(auth_login_index_path)
      end
    end

    context 'when there is an email and token but there is no matching One Time Password' do
      let(:email) { "#{SecureRandom.base36}@email.com" }

      let(:tokens) do
        {
          one_time_password_1: '1',
          one_time_password_2: '2',
          one_time_password_3: '3',
          one_time_password_4: '4',
          one_time_password_5: '5',
          one_time_password_6: '6'
        }
      end

      it 'redirects back to the new page and includes the email' do
        post '/auth/login', params: { email:, **tokens }

        expect(response).to redirect_to(new_auth_login_path(email:))
      end

      it 'displays a flash message' do
        post '/auth/login', params: { email:, **tokens }

        expect(flash[:alert]).to include('Invalid log-in code. Please try again or')
      end
    end

    context 'when there is an email and token and it has a matching One Time Password' do
      let(:user) { create(:user) }
      let(:one_time_password) { OneTimePasswordService.new(email: user.email, auth_type: :login).create! }

      let(:tokens) do
        {
          one_time_password_1: one_time_password.token[0],
          one_time_password_2: one_time_password.token[1],
          one_time_password_3: one_time_password.token[2],
          one_time_password_4: one_time_password.token[3],
          one_time_password_5: one_time_password.token[4],
          one_time_password_6: one_time_password.token[5]
        }
      end

      it 'redirects to the app page' do
        post '/auth/login', params: { email: user.email, **tokens }

        expect(response).to redirect_to(app_workspaces_path)
      end

      it 'sets a session cookie' do
        post '/auth/login', params: { email: user.email, **tokens }

        expect(session[:current_user_id]).to eq(user.id)
      end
    end
  end
end
