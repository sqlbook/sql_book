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
      let(:one_time_token_service) { instance_double(OneTimeTokenService, create!: nil) }

      before do
        allow(OneTimeTokenService).to receive(:new).and_return(one_time_token_service)
      end

      it 'creates a one time token' do
        get '/auth/signup/new', params: { email: }

        expect(one_time_token_service).to have_received(:create!)
      end

      it 'renders the one time token inputs' do
        get '/auth/signup/new', params: { email: }

        expect(response.body).to include('type="text" name="one_time_token_1"')
        expect(response.body).to include('type="text" name="one_time_token_2"')
        expect(response.body).to include('type="text" name="one_time_token_3"')
        expect(response.body).to include('type="text" name="one_time_token_4"')
        expect(response.body).to include('type="text" name="one_time_token_5"')
        expect(response.body).to include('type="text" name="one_time_token_6"')
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

      it 'redirects back to the index page' do
        post '/auth/signup', params: { email: }

        expect(response).to redirect_to(auth_signup_index_path)
      end
    end

    context 'when there is an email and token but there is no matching One Time Token' do
      let(:email) { "#{SecureRandom.base36}@email.com" }

      let(:tokens) do
        {
          one_time_token_1: '1',
          one_time_token_2: '2',
          one_time_token_3: '3',
          one_time_token_4: '4',
          one_time_token_5: '5',
          one_time_token_6: '6'
        }
      end

      it 'redirects back to the new page and includes the email' do
        post '/auth/signup', params: { email:, **tokens }

        expect(response).to redirect_to(new_auth_signup_path(email:))
      end

      it 'displays a flash message' do
        post '/auth/signup', params: { email:, **tokens }

        expect(flash[:alert]).to eq('Invalid sign-up code. Please try again or click here for a replacement code.')
      end
    end

    context 'when there is an email and token and it has a matching One Time Token' do
      let(:email) { "#{SecureRandom.base36}@email.com" }
      let(:one_time_token) { OneTimeTokenService.new(email:, auth_type: :signup).create! }

      let(:tokens) do
        {
          one_time_token_1: one_time_token.token[0],
          one_time_token_2: one_time_token.token[1],
          one_time_token_3: one_time_token.token[2],
          one_time_token_4: one_time_token.token[3],
          one_time_token_5: one_time_token.token[4],
          one_time_token_6: one_time_token.token[5]
        }
      end

      it 'directs to the app page' do
        post '/auth/signup', params: { email:, **tokens }

        expect(response).to redirect_to(app_dashboard_index_path)
      end

      it 'creates the user' do
        expect { post '/auth/signup', params: { email:, **tokens } }
          .to change { User.exists?(email:) }
          .from(false)
          .to(true)
      end

      it 'sets the session cookie' do
        post '/auth/signup', params: { email:, **tokens }

        expect(session[:current_user_id]).to eq(User.last.id)
      end
    end
  end
end
