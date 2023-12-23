# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PageHelper', type: :helper do
  describe '#body_class' do
    subject { helper.body_class }

    before do
      allow(helper).to receive(:controller_path).and_return('auth/login')
      allow(helper).to receive(:action_name).and_return('index')
    end

    it 'returns the controller and action as a class name' do
      expect(subject).to eq('auth-login-index')
    end
  end

  describe '#signup_page?' do
    subject { helper.signup_page? }

    before do
      allow(helper).to receive(:request).and_return(double(:request, path:))
    end

    context 'when the page is the sign up page' do
      let(:path) { '/auth/signup' }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when the page is not the sign up page' do
      let(:path) { '/auth/login' }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#login_page?' do
    subject { helper.login_page? }

    before do
      allow(helper).to receive(:request).and_return(double(:request, path:))
    end

    context 'when the page is the login up page' do
      let(:path) { '/auth/login' }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when the page is not the login up page' do
      let(:path) { '/auth/signup' }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#signed_in?' do
    subject { helper.signed_in? }

    before do
      allow(helper).to receive(:session).and_return(current_user_id:)
    end

    context 'when the user is logged in' do
      let(:current_user_id) { 1 }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when the user is not logged in' do
      let(:current_user_id) { nil }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end

  describe '#app_page?' do
    subject { helper.app_page? }

    before do
      allow(helper).to receive(:request).and_return(double(:request, path:))
    end

    context 'when the page is an app page' do
      let(:path) { '/app/dashboard' }

      it 'returns true' do
        expect(subject).to eq(true)
      end
    end

    context 'when the page is not an app page' do
      let(:path) { '/' }

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end
  end
end
