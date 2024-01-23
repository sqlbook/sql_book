# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth::Signups', type: :request do
  describe 'GET /auth/signup' do
    it 'renders a form to enter an email' do
      get '/auth/signup'

      expect(response.body).to include('type="email" name="email"')
    end
  end

  describe 'GET /auth/signup/new' do
    context 'when there is no email submitted' do
      it 'redirects back to the index page' do
        get '/auth/signup/new'

        expect(response).to redirect_to(auth_signup_index_path)
      end
    end

    context 'when an account with this email already exists' do
      let(:user) { create(:user) }

      it 'redirects back to the index page' do
        get '/auth/signup/new', params: { email: user.email }

        expect(response).to redirect_to(auth_signup_index_path)
      end

      it 'displays a flash message' do
        get '/auth/signup/new', params: { email: user.email }

        expect(flash[:alert]).to eq('An account with this email already exists')
      end
    end

    context 'when there is no account for this email' do
      let(:email) { "#{SecureRandom.base36}@email.com" }
      let(:one_time_password_service) { instance_double(OneTimePasswordService, create!: nil) }

      before do
        allow(OneTimePasswordService).to receive(:new).and_return(one_time_password_service)
      end

      it 'creates a one time token' do
        get '/auth/signup/new', params: { email: }

        expect(one_time_password_service).to have_received(:create!)
      end

      it 'renders the one time token inputs' do
        get '/auth/signup/new', params: { email: }

        expect(response.body).to include('type="text" name="one_time_password_1"')
        expect(response.body).to include('type="text" name="one_time_password_2"')
        expect(response.body).to include('type="text" name="one_time_password_3"')
        expect(response.body).to include('type="text" name="one_time_password_4"')
        expect(response.body).to include('type="text" name="one_time_password_5"')
        expect(response.body).to include('type="text" name="one_time_password_6"')
      end
    end
  end

  describe 'GET /auth/signup/resend' do
    context 'when there is no email provided' do
      it 'redirects back to the index page' do
        get '/auth/signup/resend'

        expect(response).to redirect_to(auth_signup_index_path)
      end
    end

    context 'when there is an email provided' do
      let(:email) { "#{SecureRandom.base36}@email.com" }

      before do
        create(:one_time_password, email:)
      end

      it 'redirects to the new auth page' do
        get '/auth/signup/resend', params: { email: }
        expect(response).to redirect_to(new_auth_signup_path(email:))
      end
    end
  end

  describe 'POST /auth/signup' do
    context 'when there is no email submitted' do
      it 'redirects back to the index page' do
        post '/auth/signup'

        expect(response).to redirect_to(auth_signup_index_path)
      end
    end

    context 'when there is an email, but no token submitted' do
      let(:email) { "#{SecureRandom.base36}@email.com" }
      let(:first_name) { 'Jim' }
      let(:last_name) { 'Morrison' }

      it 'redirects back to the index page' do
        post '/auth/signup', params: { email:, first_name:, last_name: }

        expect(response).to redirect_to(auth_signup_index_path)
      end
    end

    context 'when there is an email and token but there is no matching One Time Password' do
      let(:email) { "#{SecureRandom.base36}@email.com" }
      let(:first_name) { 'Jim' }
      let(:last_name) { 'Morrison' }

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
        post '/auth/signup', params: { email:, first_name:, last_name:, **tokens }

        expect(response).to redirect_to(new_auth_signup_path(email:))
      end

      it 'displays a flash message' do
        post '/auth/signup', params: { email:, **tokens }

        expect(flash[:alert]).to include('Invalid sign-up code. Please try again or')
      end
    end

    context 'when there is an email and token and it has a matching One Time Password' do
      let(:email) { "#{SecureRandom.base36}@email.com" }
      let(:first_name) { 'Jim' }
      let(:last_name) { 'Morrison' }
      let(:one_time_password) { OneTimePasswordService.new(email:, auth_type: :signup).create! }

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

      it 'directs to the app page' do
        post '/auth/signup', params: { email:, first_name:, last_name:, **tokens }

        expect(response).to redirect_to(new_app_workspace_path)
      end

      it 'creates the user' do
        expect { post '/auth/signup', params: { email:, first_name:, last_name:, **tokens } }
          .to change { User.exists?(email:) }
          .from(false)
          .to(true)
      end

      it 'sets the session cookie' do
        post '/auth/signup', params: { email:, first_name:, last_name:, **tokens }

        expect(session[:current_user_id]).to eq(User.last.id)
      end
    end
  end
end
