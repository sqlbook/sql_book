# frozen_string_literal: true

module App
  module Workspaces
    module DataSources
      module QueriesHelper # rubocop:disable Metrics/ModuleLength
        def query_panel_title(query:)
          query.name.presence || I18n.t('app.workspaces.queries.editor.untitled_title')
        end

        def visualization_label(chart_type:)
          config = Visualizations::ChartRegistry.fetch(chart_type)
          I18n.t(config[:label_key])
        end

        def visualization_description(chart_type:)
          config = Visualizations::ChartRegistry.fetch(chart_type)
          I18n.t(config[:description_key])
        end

        def query_editor_i18n
          {
            actions: query_editor_actions_i18n,
            query: query_editor_query_i18n,
            tabs: query_editor_tabs_i18n,
            results: query_editor_results_i18n,
            settings: query_editor_settings_i18n,
            visualizations: query_editor_visualizations_i18n,
            common: query_editor_common_i18n,
            toasts: query_editor_toasts_i18n
          }
        end

        private

        def query_editor_actions_i18n
          {
            run: I18n.t('app.workspaces.queries.editor.footer.run'),
            save_query: I18n.t('app.workspaces.queries.editor.footer.save_query'),
            save_changes: I18n.t('app.workspaces.queries.editor.footer.save_changes'),
            shortcut: I18n.t('app.workspaces.queries.editor.footer.shortcut'),
            back_to_gallery: I18n.t('app.workspaces.visualizations.actions.back_to_gallery'),
            remove_visualization: I18n.t('app.workspaces.visualizations.actions.remove')
          }
        end

        def query_editor_query_i18n
          {
            untitled_title: I18n.t('app.workspaces.queries.editor.untitled_title'),
            generating_name: I18n.t('app.workspaces.queries.editor.generating_name')
          }
        end

        def query_editor_tabs_i18n
          {
            query_results: I18n.t('app.workspaces.visualizations.tabs.query_results'),
            visualization: I18n.t('app.workspaces.visualizations.tabs.visualization'),
            settings: I18n.t('common.actions.settings')
          }
        end

        def query_editor_results_i18n
          {
            empty: I18n.t('app.workspaces.queries.editor.results.empty')
          }
        end

        def query_editor_settings_i18n
          {
            name_label: I18n.t('app.workspaces.queries.settings.name_label'),
            name_placeholder: I18n.t('app.workspaces.queries.settings.name_placeholder'),
            read_only: I18n.t('app.workspaces.queries.settings.read_only'),
            notice: I18n.t('app.workspaces.queries.settings.notice'),
            chat_source_label: I18n.t('app.workspaces.queries.settings.chat_source_label'),
            chat_source_link: I18n.t('app.workspaces.queries.settings.chat_source_link')
          }
        end

        def query_editor_visualizations_i18n
          {
            gallery_title: I18n.t('app.workspaces.visualizations.gallery.title'),
            gallery_description: I18n.t('app.workspaces.visualizations.gallery.description'),
            gallery_intro: I18n.t('app.workspaces.visualizations.gallery.intro'),
            gallery_read_only: I18n.t('app.workspaces.visualizations.gallery.read_only'),
            configured_badge: I18n.t('app.workspaces.visualizations.gallery.configured_badge'),
            coming_soon_badge: I18n.t('app.workspaces.visualizations.gallery.coming_soon_badge'),
            sections: query_editor_visualization_sections_i18n,
            form: query_editor_visualization_form_i18n,
            sharing: query_editor_visualization_sharing_i18n,
            other: query_editor_visualization_other_i18n
          }
        end

        def query_editor_visualization_sections_i18n
          {
            preview: I18n.t('app.workspaces.visualizations.sections.preview'),
            data: I18n.t('app.workspaces.visualizations.sections.data'),
            appearance: I18n.t('app.workspaces.visualizations.sections.appearance'),
            sharing: I18n.t('app.workspaces.visualizations.sections.sharing'),
            other: I18n.t('app.workspaces.visualizations.sections.other')
          }
        end

        def query_editor_visualization_form_i18n # rubocop:disable Metrics/AbcSize
          {
            theme: I18n.t('app.workspaces.visualizations.form.theme'),
            dimension_key: I18n.t('app.workspaces.visualizations.form.dimension_key'),
            value_key: I18n.t('app.workspaces.visualizations.form.value_key'),
            table_page_size: I18n.t('app.workspaces.visualizations.form.table_page_size'),
            title: I18n.t('app.workspaces.visualizations.form.title'),
            subtitle: I18n.t('app.workspaces.visualizations.form.subtitle'),
            x_axis_label: I18n.t('app.workspaces.visualizations.form.x_axis_label'),
            y_axis_label: I18n.t('app.workspaces.visualizations.form.y_axis_label'),
            donut_inner_radius: I18n.t('app.workspaces.visualizations.form.donut_inner_radius'),
            total_label: I18n.t('app.workspaces.visualizations.form.total_label'),
            legend_enabled: I18n.t('app.workspaces.visualizations.form.legend_enabled'),
            tooltip_enabled: I18n.t('app.workspaces.visualizations.form.tooltip_enabled'),
            dark_mode: I18n.t('app.workspaces.visualizations.form.dark_mode'),
            light_mode: I18n.t('app.workspaces.visualizations.form.light_mode'),
            palette: I18n.t('app.workspaces.visualizations.form.palette'),
            background_color: I18n.t('app.workspaces.visualizations.form.background_color'),
            text_color: I18n.t('app.workspaces.visualizations.form.text_color'),
            legend_text_color: I18n.t('app.workspaces.visualizations.form.legend_text_color'),
            title_color: I18n.t('app.workspaces.visualizations.form.title_color'),
            subtitle_color: I18n.t('app.workspaces.visualizations.form.subtitle_color'),
            axis_line_color: I18n.t('app.workspaces.visualizations.form.axis_line_color'),
            axis_label_color: I18n.t('app.workspaces.visualizations.form.axis_label_color'),
            split_line_color: I18n.t('app.workspaces.visualizations.form.split_line_color'),
            tooltip_background_color: I18n.t('app.workspaces.visualizations.form.tooltip_background_color'),
            tooltip_text_color: I18n.t('app.workspaces.visualizations.form.tooltip_text_color'),
            raw_json: I18n.t('app.workspaces.visualizations.form.raw_json')
          }
        end

        def query_editor_visualization_sharing_i18n
          {
            title: I18n.t('app.workspaces.visualizations.sharing.title'),
            body: I18n.t('app.workspaces.visualizations.sharing.body')
          }
        end

        def query_editor_visualization_other_i18n
          {
            description: I18n.t('app.workspaces.visualizations.other.description')
          }
        end

        def query_editor_common_i18n
          {
            close: I18n.t('common.actions.close'),
            default_badge: I18n.t('app.workspaces.settings.branding.table.default_badge'),
            enabled: I18n.t('common.states.enabled'),
            disabled: I18n.t('common.states.disabled')
          }
        end

        def query_editor_toasts_i18n
          {
            save_created_title: I18n.t('app.workspaces.queries.editor.toasts.save_created.title'),
            save_created_body: I18n.t('app.workspaces.queries.editor.toasts.save_created.body'),
            save_updated_title: I18n.t('app.workspaces.queries.editor.toasts.save_updated.title'),
            save_updated_body: I18n.t('app.workspaces.queries.editor.toasts.save_updated.body'),
            already_saved_title: I18n.t('app.workspaces.queries.editor.toasts.already_saved.title'),
            already_saved_body: I18n.t('app.workspaces.queries.editor.toasts.already_saved.body'),
            save_failed_title: I18n.t('app.workspaces.queries.editor.toasts.save_failed.title'),
            run_failed_title: I18n.t('app.workspaces.queries.editor.toasts.run_failed.title'),
            name_required_title: I18n.t('app.workspaces.queries.editor.toasts.name_required.title'),
            name_required_body: I18n.t('app.workspaces.queries.editor.toasts.name_required.body'),
            run_required_title: I18n.t('app.workspaces.queries.editor.toasts.run_required.title'),
            run_required_body: I18n.t('app.workspaces.queries.editor.toasts.run_required.body')
          }
        end
      end
    end
  end
end
