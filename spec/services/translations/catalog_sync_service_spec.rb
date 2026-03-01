# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Translations::CatalogSyncService, type: :service do
  describe '.sync_from_locale_file!' do
    before do
      TranslationValueRevision.delete_all
      TranslationValue.delete_all
      TranslationKey.delete_all
    end

    it 'adds email area metadata and used_in marker for mailer keys' do
      described_class.sync_from_locale_file!

      key = TranslationKey.find_by!(key: 'mailers.account.subjects.account_deletion_confirmed')
      expect(key.area_tags).to include('mailers', 'email')
      expect(key.type_tags).to include('email_subject')
      expect(key.used_in).to include(a_hash_including('label' => 'Email'))
    end

    it 'tags action copy as button and title copy with heading tags where mapped' do
      described_class.sync_from_locale_file!

      button_key = TranslationKey.find_by!(key: 'common.actions.save')
      heading_key = TranslationKey.find_by!(key: 'admin.translations.title')

      expect(button_key.type_tags).to include('button')
      expect(heading_key.type_tags).to include('h1')
    end

    it 'sets page link metadata for account settings copy' do
      described_class.sync_from_locale_file!

      key = TranslationKey.find_by!(key: 'app.account_settings.general.description')
      expect(key.used_in).to include(
        a_hash_including('label' => 'Account settings page', 'path' => '/app/account-settings')
      )
    end

    it 'marks common keys as shared copy' do
      described_class.sync_from_locale_file!

      key = TranslationKey.find_by!(key: 'common.actions.save')
      expect(key.area_tags).to include('common')
      expect(key.used_in).to include(a_hash_including('label' => 'Shared copy'))
    end
  end
end
