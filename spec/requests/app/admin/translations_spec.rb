# frozen_string_literal: true

# rubocop:disable Style/FormatStringToken
require 'rails_helper'

RSpec.describe 'App::Admin::Translations', type: :request do
  describe 'GET /app/admin/translations' do
    context 'when user is not authenticated' do
      it 'redirects to login' do
        get '/app/admin/translations'

        expect(response).to redirect_to(auth_login_index_path)
      end
    end

    context 'when user is authenticated but not super admin' do
      let(:user) { create(:user, super_admin: false) }

      before { sign_in(user) }

      it 'redirects to app workspaces with an error toast' do
        get '/app/admin/translations'

        expect(response).to redirect_to(app_workspaces_path)
        expect(flash[:toast]).to include(
          type: 'error',
          title: I18n.t('toasts.admin.access_forbidden.title'),
          body: I18n.t('toasts.admin.access_forbidden.body')
        )
      end
    end

    context 'when user is a super admin' do
      let(:user) { create(:user, super_admin: true) }

      before { sign_in(user) }

      it 'renders the translations manager' do
        get '/app/admin/translations'

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t('admin.translations.title'))
      end

      it 'filters to duplicate english text when requested' do
        duplicate_one = TranslationKey.create!(
          key: 'test.duplicate.one',
          area_tags: ['admin'],
          type_tags: ['copy'],
          used_in: []
        )
        duplicate_two = TranslationKey.create!(
          key: 'test.duplicate.two',
          area_tags: ['admin'],
          type_tags: ['copy'],
          used_in: []
        )
        unique_key = TranslationKey.create!(
          key: 'test.unique',
          area_tags: ['admin'],
          type_tags: ['copy'],
          used_in: []
        )

        TranslationValue.create!(translation_key: duplicate_one, locale: 'en', value: 'Shared label')
        TranslationValue.create!(translation_key: duplicate_two, locale: 'en', value: 'Shared label')
        TranslationValue.create!(translation_key: unique_key, locale: 'en', value: 'Unique label')

        get '/app/admin/translations', params: { status: 'duplicate_english' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('test.duplicate.one')
        expect(response.body).to include('test.duplicate.two')
        expect(response.body).not_to include('test.unique')
      end
    end

    context 'when user is in bootstrap allowlist' do
      let(:user) { create(:user, email: 'owner@sqlbook.com', super_admin: false) }

      before do
        sign_in(user)
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('SUPER_ADMIN_BOOTSTRAP_EMAILS', '').and_return(user.email)
      end

      it 'grants super admin and allows access' do
        get '/app/admin/translations'

        expect(response).to have_http_status(:ok)
        expect(user.reload.super_admin).to be(true)
      end
    end
  end

  describe 'PATCH /app/admin/translations' do
    let(:user) { create(:user, super_admin: true) }
    let!(:translation_key) do
      TranslationKey.create!(
        key: 'toasts.generic_error.title',
        area_tags: ['toasts'],
        type_tags: ['title'],
        used_in: []
      )
    end
    let!(:english_value) do
      TranslationValue.create!(
        translation_key:,
        locale: 'en',
        value: 'Something went wrong'
      )
    end

    before { sign_in(user) }

    it 'updates values and metadata in bulk' do
      patch '/app/admin/translations', params: {
        rows: {
          translation_key.id.to_s => {
            id: translation_key.id,
            area_tags: 'toasts,global',
            type_tags: 'title,toast',
            en: 'Something went wrong',
            es: 'Algo salió mal'
          }
        }
      }

      expect(response).to redirect_to(app_admin_translations_path)
      expect(translation_key.reload.area_tags).to contain_exactly('toasts', 'global')
      expect(translation_key.type_tags).to contain_exactly('title', 'toast')
      expect(translation_key.used_in).to eq([{ 'label' => 'Toast' }])
      expect(TranslationValue.find_by(translation_key:, locale: 'es')&.value).to eq('Algo salió mal')
      expect(TranslationValueRevision.exists?(locale: 'es')).to be(true)
    end
  end

  describe 'POST /app/admin/translations/:id/translate-missing' do
    let(:user) { create(:user, super_admin: true) }
    let!(:translation_key) do
      TranslationKey.create!(
        key: 'sample.key',
        area_tags: ['sample'],
        type_tags: ['copy'],
        used_in: []
      )
    end
    let!(:english_value) do
      TranslationValue.create!(
        translation_key:,
        locale: 'en',
        value: 'Hello %{name}'
      )
    end

    before { sign_in(user) }

    it 'stores a translation draft suggestion in flash' do
      service = instance_double(Translations::OpenaiTranslationService, call: 'Hola %{name}')
      allow(Translations::OpenaiTranslationService).to receive(:new).and_return(service)

      post translate_missing_app_admin_translation_path(translation_key), params: { target_locale: 'es' }

      expect(response).to redirect_to(app_admin_translations_path(target_locale: 'es'))
      expect(flash[:translation_suggestions]).to eq(
        translation_key.id.to_s => { 'es' => 'Hola %{name}' }
      )
    end

    it 'rejects drafts with placeholder mismatch' do
      service = instance_double(Translations::OpenaiTranslationService, call: 'Hola')
      allow(Translations::OpenaiTranslationService).to receive(:new).and_return(service)

      post translate_missing_app_admin_translation_path(translation_key), params: { target_locale: 'es' }

      expect(response).to redirect_to(app_admin_translations_path(target_locale: 'es'))
      expect(flash[:toast]).to include(
        type: 'error',
        title: I18n.t('toasts.admin.translations.translate_missing_failed.title'),
        body: I18n.t('toasts.admin.translations.placeholder_mismatch.body')
      )
    end
  end

  describe 'GET /app/admin/translations/:id/history' do
    let(:user) { create(:user, super_admin: true) }
    let!(:translation_key) do
      TranslationKey.create!(
        key: 'sample.history.key',
        area_tags: ['sample'],
        type_tags: ['copy'],
        used_in: []
      )
    end
    let!(:translation_value) do
      TranslationValue.create!(
        translation_key:,
        locale: 'es',
        value: 'Hola'
      )
    end
    let!(:revision) do
      TranslationValueRevision.create!(
        translation_value:,
        locale: 'es',
        old_value: 'Buenos dias',
        new_value: 'Hola',
        changed_by: user,
        change_source: 'manual'
      )
    end

    before { sign_in(user) }

    it 'returns revision history as json' do
      get history_app_admin_translation_path(translation_key)

      expect(response).to have_http_status(:ok)
      payload = response.parsed_body
      expect(payload.first['locale']).to eq('es')
      expect(payload.first['new_value']).to eq('Hola')
      expect(payload.first['change_source']).to eq('manual')
    end
  end
end
# rubocop:enable Style/FormatStringToken
