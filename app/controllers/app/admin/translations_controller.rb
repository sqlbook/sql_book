# frozen_string_literal: true

module App
  module Admin
    class TranslationsController < BaseController # rubocop:disable Metrics/ClassLength
      before_action :sync_catalog!

      def index
        @translation_suggestions = flash[:translation_suggestions] || {}
        load_index_collections
      end

      def update
        success = Translations::UpdateService.new(
          actor: current_user,
          rows_params: translation_rows_params
        ).call

        flash[:toast] = if success
                          success_toast
                        else
                          error_toast
                        end

        redirect_to app_admin_translations_path(filter_params)
      end

      def translate_missing
        outcome = translation_outcome
        flash[:toast] = outcome.fetch(:toast)
        flash[:translation_suggestions] = outcome[:suggestions] if outcome[:suggestions]
        redirect_with_filters
      rescue Translations::OpenaiTranslationService::ConfigurationError => e
        handle_translate_configuration_error(e)
      rescue Translations::OpenaiTranslationService::RequestError => e
        handle_translate_request_error(e)
      end

      def history
        translation_key = TranslationKey.find(params[:id])
        revisions = TranslationValueRevision.joins(:translation_value)
          .where(translation_values: { translation_key_id: translation_key.id })
          .order(created_at: :desc)
          .limit(50)

        render json: revisions.map { |revision| revision_payload(revision:) }
      end

      private

      def load_index_collections
        @translation_keys = filtered_translation_keys
        @area_tags = available_tags(:area_tags)
        @type_tags = available_tags(:type_tags)
      end

      def available_tags(column)
        TranslationKey.distinct.order(column).pluck(column).flatten.compact.uniq.sort
      end

      def filtered_translation_keys
        scope = TranslationKey.includes(:translation_values).ordered
        scope = apply_tag_filters(scope)
        scope = apply_search_filter(scope)
        apply_missing_filter(scope)
      end

      def apply_tag_filters(scope)
        updated_scope = scope
        updated_scope = updated_scope.for_area_tag(filter_params[:area_tag]) if filter_params[:area_tag].present?
        updated_scope = updated_scope.for_type_tag(filter_params[:type_tag]) if filter_params[:type_tag].present?
        updated_scope
      end

      def apply_search_filter(scope)
        return scope if filter_params[:q].blank?

        query = "%#{filter_params[:q].strip.downcase}%"
        scope.left_joins(:translation_values)
          .where(
            'LOWER(translation_keys.key) LIKE :query OR LOWER(translation_values.value) LIKE :query',
            query:
          ).distinct
      end

      def apply_missing_filter(scope)
        return scope unless ActiveModel::Type::Boolean.new.cast(filter_params[:missing_only])

        scope.where.not(
          id: TranslationValue.where(locale: requested_target_locale)
                              .where.not(value: [nil, ''])
                              .select(:translation_key_id)
        )
      end

      def source_translation_for(translation_key:)
        translation_key.translation_values.find_by(locale: I18n.default_locale.to_s)&.value.to_s
      end

      def translation_outcome
        translation_key = TranslationKey.find(params[:id])
        target_locale = requested_target_locale
        source_value = source_translation_for(translation_key:)
        return translate_missing_failed_outcome if source_value.blank?
        return translate_not_needed_outcome if target_translation_present?(translation_key:, target_locale:)

        translated_text = generated_translation(translation_key:, source_value:, target_locale:)
        return placeholder_mismatch_outcome unless placeholder_valid?(source_value:, translated_text:)

        success_translation_outcome(translation_key:, target_locale:, translated_text:)
      end

      def target_translation_present?(translation_key:, target_locale:)
        translation_key.translation_values.find_by(locale: target_locale)&.value.to_s.present?
      end

      def generated_translation(translation_key:, source_value:, target_locale:)
        Translations::OpenaiTranslationService.new(
          source_text: source_value,
          source_locale: I18n.default_locale.to_s,
          target_locale:,
          translation_key:
        ).call
      end

      def placeholder_valid?(source_value:, translated_text:)
        Translations::PlaceholderValidator.valid_placeholders?(source: source_value, candidate: translated_text)
      end

      def success_translation_outcome(translation_key:, target_locale:, translated_text:)
        {
          suggestions: {
            translation_key.id.to_s => {
              target_locale => translated_text
            }
          },
          toast: translate_missing_success_toast
        }
      end

      def translate_missing_failed_outcome
        {
          toast: {
            type: 'error',
            title: I18n.t('toasts.admin.translations.translate_missing_failed.title'),
            body: I18n.t('toasts.admin.translations.translate_missing_failed.body')
          }
        }
      end

      def translate_not_needed_outcome
        {
          toast: {
            type: 'information',
            title: I18n.t('toasts.admin.translations.translate_not_needed.title'),
            body: I18n.t('toasts.admin.translations.translate_not_needed.body')
          }
        }
      end

      def placeholder_mismatch_outcome
        {
          toast: {
            type: 'error',
            title: I18n.t('toasts.admin.translations.translate_missing_failed.title'),
            body: I18n.t('toasts.admin.translations.placeholder_mismatch.body')
          }
        }
      end

      def requested_target_locale
        locale = params[:target_locale].to_s.presence || 'es'
        return locale if TranslationValue::SUPPORTED_LOCALES.include?(locale)

        'es'
      end

      def translation_rows_params
        raw_rows = params[:rows]
        return {} unless raw_rows.respond_to?(:to_unsafe_h)

        raw_rows.to_unsafe_h
      end

      def sync_catalog!
        Translations::CatalogSyncService.sync_from_locale_file!
      end

      def filter_params
        @filter_params ||= params.permit(:q, :area_tag, :type_tag, :missing_only, :target_locale)
      end

      def redirect_with_filters
        redirect_to app_admin_translations_path(filter_params)
      end

      def handle_translate_configuration_error(error)
        Rails.logger.error("Translation generation misconfigured: #{error.message}")
        flash[:toast] = {
          type: 'error',
          title: I18n.t('toasts.admin.translations.translate_missing_failed.title'),
          body: I18n.t('toasts.admin.translations.openai_missing_config.body')
        }
        redirect_with_filters
      end

      def handle_translate_request_error(error)
        Rails.logger.error("Translation generation failed: #{error.message}")
        flash[:toast] = translate_missing_failed_outcome.fetch(:toast)
        redirect_with_filters
      end

      def translate_missing_success_toast
        {
          type: 'success',
          title: I18n.t('toasts.admin.translations.translate_missing_success.title'),
          body: I18n.t('toasts.admin.translations.translate_missing_success.body')
        }
      end

      def success_toast
        {
          type: 'success',
          title: I18n.t('toasts.admin.translations.saved.title'),
          body: I18n.t('toasts.admin.translations.saved.body')
        }
      end

      def error_toast
        {
          type: 'error',
          title: I18n.t('toasts.admin.translations.save_failed.title'),
          body: I18n.t('toasts.admin.translations.save_failed.body')
        }
      end

      def revision_payload(revision:)
        {
          locale: revision.locale,
          old_value: revision.old_value,
          new_value: revision.new_value,
          change_source: revision.change_source,
          changed_by: revision.changed_by&.full_name,
          changed_at: revision.created_at.iso8601
        }
      end
    end # rubocop:enable Metrics/ClassLength
  end
end
