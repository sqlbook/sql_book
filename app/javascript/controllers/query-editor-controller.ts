import { Controller } from '@hotwired/stimulus';

type QueryResultPayload = {
  error: boolean;
  error_message?: string | null;
  columns: string[];
  rows: Array<Array<string | number | boolean | null>>;
  row_count: number;
} | null;

type ThemeEntry = {
  reference_key: string;
  name: string;
  default: boolean;
  read_only: boolean;
  system_theme: boolean;
  theme_json_dark: Record<string, unknown>;
  theme_json_light: Record<string, unknown>;
};

type VisualizationType = {
  chart_type: string;
  icon: string;
  label: string;
  description: string;
  renderer: string;
};

type VisualizationDraft = {
  chart_type: string;
  theme_reference: string;
  renderer: string;
  data_config: Record<string, unknown>;
  other_config: Record<string, unknown>;
  appearance_config_dark: Record<string, unknown>;
  appearance_config_light: Record<string, unknown>;
  appearance_editor_dark: Record<string, string>;
  appearance_editor_light: Record<string, string>;
  appearance_raw_json_dark: string;
  appearance_raw_json_light: string;
};

type QueryPayload = {
  id: number | null;
  saved: boolean;
  name: string | null;
  sql: string | null;
  data_source_id: number;
  canonical_path?: string | null;
};

type BootstrapPayload = {
  query: QueryPayload;
  result: QueryResultPayload;
  run_token?: string | null;
  visualizations: VisualizationDraft[];
  available_visualization_types: VisualizationType[];
  theme_library: ThemeEntry[];
  chat_source?: { path: string } | null;
  active_tab: 'query_results' | 'visualization' | 'settings';
};

type TranslationPayload = Record<string, any>;

export default class extends Controller<HTMLDivElement> {
  static targets = [
    'bootstrap',
    'translations',
    'input',
    'dataSourceSelect',
    'dataSourceSettingsLink',
    'schema',
    'schemaSelect',
    'queryLibrary',
    'tabButton',
    'panelTitle',
    'resultsPane',
    'visualizationPane',
    'settingsPane',
    'runButton',
    'runHint',
    'saveButton',
    'saveLabel',
    'saveCount'
  ];

  static values = {
    runUrl: String,
    saveUrl: String,
    queryBaseUrl: String,
    dataSourceSettingsBaseUrl: String,
    readOnly: Boolean
  };

  declare readonly bootstrapTarget: HTMLScriptElement;
  declare readonly translationsTarget: HTMLScriptElement;
  declare readonly inputTarget: HTMLTextAreaElement;
  declare readonly dataSourceSelectTarget: HTMLSelectElement;
  declare readonly dataSourceSettingsLinkTarget: HTMLAnchorElement;
  declare readonly schemaTarget: HTMLDivElement;
  declare readonly schemaSelectTarget: HTMLSelectElement;
  declare readonly queryLibraryTarget: HTMLDivElement;
  declare readonly tabButtonTargets: HTMLButtonElement[];
  declare readonly panelTitleTarget: HTMLElement;
  declare readonly resultsPaneTarget: HTMLElement;
  declare readonly visualizationPaneTarget: HTMLElement;
  declare readonly settingsPaneTarget: HTMLElement;
  declare readonly runButtonTarget: HTMLButtonElement;
  declare readonly runHintTarget: HTMLElement;
  declare readonly saveButtonTarget: HTMLButtonElement;
  declare readonly saveLabelTarget: HTMLElement;
  declare readonly saveCountTarget: HTMLElement;

  declare readonly hasSchemaTarget: boolean;
  declare readonly hasSchemaSelectTarget: boolean;

  declare readonly runUrlValue: string;
  declare readonly saveUrlValue: string;
  declare readonly queryBaseUrlValue: string;
  declare readonly dataSourceSettingsBaseUrlValue: string;
  declare readonly readOnlyValue: boolean;

  private bootstrap!: BootstrapPayload;
  private i18n!: TranslationPayload;
  private query!: QueryPayload;
  private result: QueryResultPayload = null;
  private runToken: string | null = null;
  private lastSuccessfulFingerprint: string | null = null;
  private lastSuccessfulResult: QueryResultPayload = null;
  private visualizations: Record<string, VisualizationDraft> = {};
  private baselineQuery!: QueryPayload;
  private baselineVisualizations!: Record<string, VisualizationDraft>;
  private activeTab: 'query_results' | 'visualization' | 'settings' = 'query_results';
  private activeVisualizationType: string | null = null;
  private generatedNameLocked = false;
  private generatedNameAttempted = false;

  connect(): void {
    this.bootstrap = this.parseJsonTarget<BootstrapPayload>(this.bootstrapTarget);
    this.i18n = this.parseJsonTarget<TranslationPayload>(this.translationsTarget);
    this.query = deepClone(this.bootstrap.query);
    this.result = deepClone(this.bootstrap.result);
    this.runToken = this.bootstrap.run_token || null;
    this.lastSuccessfulFingerprint = this.runToken ? this.currentFingerprint() : null;
    this.lastSuccessfulResult = deepClone(this.bootstrap.result);
    this.visualizations = this.indexVisualizations(this.bootstrap.visualizations);
    this.baselineQuery = this.snapshotQuery();
    this.baselineVisualizations = this.snapshotVisualizations();
    this.activeTab = this.bootstrap.active_tab || 'query_results';
    this.generatedNameLocked = Boolean(this.query.name);
    this.generatedNameAttempted = Boolean(this.query.saved || this.query.name);

    this.restorePendingToast();
    this.renderAll();
  }

  change(event: Event): void {
    const target = event.target as HTMLTextAreaElement;
    this.query.sql = target.value;
    this.syncResultForCurrentSql();
    this.renderQueryLibraryVisibility();
    this.updateTextareaRows();
    this.renderFooter();
    this.renderResultsPane();
    if (this.activeTab === 'visualization') this.renderVisualizationPane();
  }

  changeSource(event: Event): void {
    const target = event.target as HTMLSelectElement;
    const selectedId = target.value;
    if (!selectedId) return;

    const url = this.baseQueryUrl(selectedId);
    const nextUrl = new URL(url, window.location.origin);
    if (this.query.sql?.trim()) nextUrl.searchParams.set('query', this.query.sql);
    if (this.query.name?.trim()) nextUrl.searchParams.set('name', this.query.name);
    nextUrl.searchParams.set('tab', this.activeTab);
    this.turboVisit(nextUrl.pathname + nextUrl.search);
  }

  changeSchema(event: Event): void {
    const target = event.target as HTMLSelectElement;
    this.syncSchemaTable(target.value);
  }

  toggleSchema(event: Event): void {
    if (!this.hasSchemaTarget) return;

    this.schemaTarget.classList.toggle('hide');
    const button = (event.currentTarget as HTMLElement) || null;
    button?.classList.toggle('active');
  }

  applySuggestion(event: Event): void {
    const target = event.currentTarget as HTMLElement;
    const suggestion = target.textContent?.trim();
    if (!suggestion) return;

    this.query.sql = suggestion;
    this.inputTarget.value = suggestion;
    this.generatedNameLocked = false;
    this.syncResultForCurrentSql();
    this.renderQueryLibraryVisibility();
    this.updateTextareaRows();
    this.renderFooter();
    this.renderResultsPane();
  }

  handleKeydown(event: KeyboardEvent): void {
    if ((event.metaKey || event.ctrlKey) && event.key === 'Enter') {
      event.preventDefault();
      this.runQuery();
    }
  }

  selectTab(event: Event): void {
    const target = event.currentTarget as HTMLElement;
    const tab = target.dataset.tab as 'query_results' | 'visualization' | 'settings' | undefined;
    if (!tab) return;

    this.activeTab = tab;
    this.persistTabParam();
    this.renderTabs();
    this.renderPaneVisibility();
    if (tab === 'query_results') this.renderResultsPane();
    if (tab === 'visualization') this.renderVisualizationPane();
    if (tab === 'settings') this.renderSettingsPane();
  }

  selectVisualization(event: Event): void {
    const target = event.currentTarget as HTMLElement;
    const chartType = target.dataset.chartType?.trim();
    if (!chartType) return;

    if (!this.visualizations[chartType]) {
      this.visualizations[chartType] = buildDefaultVisualizationDraft({
        chartType,
        themeReference: this.defaultThemeReference(),
        columns: this.result?.columns || [],
        visualizationTypes: this.availableVisualizationTypes()
      });
    }

    this.activeVisualizationType = chartType;
    this.renderVisualizationPane();
    this.renderFooter();
  }

  backToVisualizationGallery(): void {
    this.activeVisualizationType = null;
    this.renderVisualizationPane();
  }

  removeVisualization(): void {
    if (!this.activeVisualizationType) return;

    delete this.visualizations[this.activeVisualizationType];
    this.activeVisualizationType = null;
    this.renderVisualizationPane();
    this.renderFooter();
  }

  changeVisualizationField(event: Event): void {
    if (!this.activeVisualizationType) return;

    const target = event.target as HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement;
    const draft = this.visualizations[this.activeVisualizationType];
    if (!draft) return;

    const scope = target.dataset.scope;
    const key = target.dataset.key;
    const mode = target.dataset.mode;
    if (!scope || !key) return;

    const value = normalizeFieldValue(target.value);

    if (scope === 'root') {
      (draft as Record<string, unknown>)[key] = value;
    } else if (scope === 'data_config' || scope === 'other_config') {
      const container = draft[scope] as Record<string, unknown>;
      container[key] = value;
    } else if (scope === 'appearance_editor' && mode) {
      const appearanceKey = `appearance_editor_${mode}` as 'appearance_editor_dark' | 'appearance_editor_light';
      draft[appearanceKey][key] = String(value ?? '');
    } else if (scope === 'appearance_raw_json' && mode) {
      const rawKey = `appearance_raw_json_${mode}` as 'appearance_raw_json_dark' | 'appearance_raw_json_light';
      draft[rawKey] = String(value ?? '');
    }

    this.renderFooter();
    this.renderVisualizationPreviewOnly();
  }

  changeName(event: Event): void {
    const target = event.target as HTMLInputElement;
    this.query.name = target.value;
    this.generatedNameLocked = Boolean(this.query.name?.trim());
    this.renderPanelTitle();
    this.renderFooter();
  }

  runQuery(): void {
    if (!this.runEnabled()) return;

    this.dispatch('open-panel', { bubbles: true });

    this.requestJson(this.runUrlValue, {
      data_source_id: this.currentDataSourceId(),
      name: this.query.name,
      sql: this.query.sql,
      request_generated_name: !this.query.saved && !this.generatedNameLocked && !this.generatedNameAttempted
    }).then((payload) => {
      const data = payload.data || {};
      this.result = data.result || null;
      this.lastSuccessfulResult = deepClone(this.result);
      this.runToken = data.run_token || null;
      this.lastSuccessfulFingerprint = this.runToken ? this.currentFingerprint() : null;
      if (!this.query.saved && this.result && !this.result.error) this.generatedNameAttempted = true;

      if (data.generated_name && !this.generatedNameLocked) {
        this.query.name = data.generated_name;
        this.generatedNameLocked = true;
      }

      this.renderAll();
    }).catch((error) => {
      this.showToast('error', this.translate('toasts.run_failed_title'), error.message || '');
    });
  }

  saveQuery(): void {
    if (!this.saveEnabled()) {
      if (!this.query.name?.trim()) {
        this.activeTab = 'settings';
        this.renderTabs();
        this.renderPaneVisibility();
        this.renderSettingsPane();
        this.showToast(
          'error',
          this.translate('toasts.name_required_title'),
          this.translate('toasts.name_required_body')
        );
      }
      return;
    }

    this.requestJson(this.saveUrlValue, {
      query_id: this.query.id,
      data_source_id: this.currentDataSourceId(),
      name: this.query.name,
      sql: this.query.sql,
      run_token: this.runToken,
      visualizations: this.visualizationPayloadsForSave()
    }).then((payload) => {
      const data = payload.data || {};
      const savedQuery = data.query;
      if (!savedQuery) return;

      if (data.save_outcome === 'already_saved' && savedQuery.canonical_path) {
        this.persistPendingToast({
          type: 'information',
          title: this.translate('toasts.already_saved_title'),
          body: interpolate(this.translate('toasts.already_saved_body'), { name: savedQuery.name || '' })
        });
        this.turboVisit(savedQuery.canonical_path);
        return;
      }

      this.query.id = savedQuery.id;
      this.query.saved = Boolean(savedQuery.saved);
      this.query.name = savedQuery.name;
      this.query.sql = savedQuery.sql;
      this.query.data_source_id = savedQuery.data_source_id;
      this.query.canonical_path = savedQuery.canonical_path;

      this.baselineQuery = this.snapshotQuery();
      this.baselineVisualizations = this.snapshotVisualizations();

      if (savedQuery.canonical_path) {
        window.history.replaceState({}, '', savedQuery.canonical_path + `?tab=${this.activeTab}`);
      }

      const created = data.save_outcome === 'created';
      this.showToast(
        'success',
        this.translate(created ? 'toasts.save_created_title' : 'toasts.save_updated_title'),
        this.translate(created ? 'toasts.save_created_body' : 'toasts.save_updated_body')
      );
      this.renderAll();
    }).catch((error) => {
      if (!this.query.name?.trim()) {
        this.activeTab = 'settings';
        this.renderTabs();
        this.renderPaneVisibility();
        this.renderSettingsPane();
      }

      this.showToast('error', this.translate('toasts.save_failed_title'), error.message || '');
    });
  }

  private renderAll(): void {
    this.inputTarget.value = this.query.sql || '';
    this.dataSourceSelectTarget.value = String(this.currentDataSourceId());
    this.updateTextareaRows();
    this.renderQueryLibraryVisibility();
    this.syncSourceSettingsLink();
    this.renderPanelTitle();
    this.renderTabs();
    this.renderPaneVisibility();
    this.renderResultsPane();
    this.renderVisualizationPane();
    this.renderSettingsPane();
    this.renderFooter();
    if (this.hasSchemaSelectTarget) this.syncSchemaTable(this.schemaSelectTarget.value);
  }

  private renderPanelTitle(): void {
    this.panelTitleTarget.textContent = this.queryTitle();
  }

  private renderTabs(): void {
    this.tabButtonTargets.forEach((button) => {
      button.classList.toggle('active', button.dataset.tab === this.activeTab);
    });
  }

  private renderPaneVisibility(): void {
    this.resultsPaneTarget.hidden = this.activeTab !== 'query_results';
    this.visualizationPaneTarget.hidden = this.activeTab !== 'visualization';
    this.settingsPaneTarget.hidden = this.activeTab !== 'settings';
  }

  private renderResultsPane(): void {
    if (this.result === null) {
      this.resultsPaneTarget.innerHTML = `<p class="gray-300">${escapeHtml(this.translate('results.empty'))}</p>`;
      return;
    }

    if (this.result.error) {
      this.resultsPaneTarget.innerHTML = `<p class="red-500">${escapeHtml(this.result.error_message || '')}</p>`;
      return;
    }

    this.resultsPaneTarget.innerHTML = queryResultsTableMarkup(this.result, 10);
  }

  private renderVisualizationPane(): void {
    if (this.activeVisualizationType) {
      this.visualizationPaneTarget.innerHTML = this.visualizationEditorMarkup();
      this.renderVisualizationPreviewOnly();
      return;
    }

    this.visualizationPaneTarget.innerHTML = this.visualizationGalleryMarkup();
  }

  private renderVisualizationPreviewOnly(): void {
    const host = this.visualizationPaneTarget.querySelector('[data-query-editor-preview-host]');
    if (!(host instanceof HTMLElement) || !this.activeVisualizationType) return;

    host.innerHTML = this.visualizationPreviewMarkup(this.visualizations[this.activeVisualizationType]);
  }

  private renderSettingsPane(): void {
    if (this.readOnlyValue) {
      this.settingsPaneTarget.innerHTML = `<p>${escapeHtml(this.translate('settings.read_only'))}</p>`;
      return;
    }

    const chatSource = this.bootstrap.chat_source;
    this.settingsPaneTarget.innerHTML = `
      <div class="new-query-form">
        <label class="label block">${escapeHtml(this.translate('settings.name_label'))}</label>
        <input
          type="text"
          class="input block fluid"
          placeholder="${escapeAttribute(this.translate('settings.name_placeholder'))}"
          value="${escapeAttribute(this.query.name || '')}"
          data-action="input->query-editor#changeName">
      </div>
      ${chatSource?.path ? `
        <p class="small gray-300 mt24">
          <strong>${escapeHtml(this.translate('settings.chat_source_label'))}:</strong>
          <a class="link secondary" href="${escapeAttribute(chatSource.path)}" target="_blank" rel="noopener noreferrer">
            ${escapeHtml(this.translate('settings.chat_source_link'))}
          </a>
        </p>
      ` : ''}
    `;
  }

  private renderFooter(): void {
    this.runButtonTarget.textContent = this.translate('actions.run');
    this.runHintTarget.textContent = this.translate('actions.shortcut');
    this.runButtonTarget.disabled = !this.runEnabled();

    this.saveLabelTarget.textContent = this.query.saved ? this.translate('actions.save_changes') : this.translate('actions.save_query');
    this.saveCountTarget.textContent = this.query.saved && this.dirtyCount() > 0 ? ` ${this.dirtyCount()}` : '';
    this.saveButtonTarget.disabled = !this.saveEnabled();
  }

  private visualizationGalleryMarkup(): string {
    const cards = this.availableVisualizationTypes().map((visualizationType) => {
      const configured = Boolean(this.visualizations[visualizationType.chart_type]);
      return `
        <button
          type="button"
          class="visualization-gallery__card"
          data-chart-type="${escapeAttribute(visualizationType.chart_type)}"
          data-action="query-editor#selectVisualization">
          <i class="${escapeAttribute(visualizationType.icon)}" aria-hidden="true"></i>
          <span class="visualization-gallery__label">${escapeHtml(visualizationType.label)}</span>
          <span class="visualization-gallery__description">${escapeHtml(visualizationType.description)}</span>
          ${configured ? `<span class="visualization-gallery__badge">${escapeHtml(this.translate('visualizations.configured_badge'))}</span>` : ''}
        </button>
      `;
    }).join('');

    if (this.readOnlyValue) {
      return `
        <div class="visualization-gallery">
          <div class="visualization-gallery__header">
            <h4 class="cream-250">${escapeHtml(this.translate('visualizations.gallery_title'))}</h4>
            <p class="gray-300">${escapeHtml(this.translate('visualizations.gallery_description'))}</p>
          </div>
          <p class="gray-300">${escapeHtml(this.translate('visualizations.gallery_read_only'))}</p>
        </div>
      `;
    }

    return `
      <div class="visualization-gallery">
        <div class="visualization-gallery__header">
          <h4 class="cream-250">${escapeHtml(this.translate('visualizations.gallery_title'))}</h4>
          <p class="gray-300">${escapeHtml(this.translate('visualizations.gallery_description'))}</p>
        </div>
        <div class="visualization-gallery__grid">
          ${cards}
        </div>
      </div>
    `;
  }

  private visualizationEditorMarkup(): string {
    const draft = this.currentVisualizationDraft();
    if (!draft) return '';

    const columns = this.result?.columns || [];
    const dataConfig = resolvedDataConfig(draft, columns);
    const otherConfig = resolvedOtherConfig(draft, columns);
    const themeOptions = this.themeLibrary().map((theme) => {
      return optionMarkup(
        theme.reference_key,
        theme.name + (theme.default ? ` · ${this.translate('common.default_badge')}` : ''),
        draft.theme_reference
      );
    }).join('');

    return `
      <div class="visualization-editor">
        <section class="visualization-editor__section">
          <div class="visualization-editor__section-heading">
            <button type="button" class="link secondary" data-action="query-editor#backToVisualizationGallery">
              ${escapeHtml(this.translate('actions.back_to_gallery'))}
            </button>
            ${this.readOnlyValue ? '' : `
              <button type="button" class="link secondary" data-action="query-editor#removeVisualization">
                ${escapeHtml(this.translate('actions.remove_visualization'))}
              </button>
            `}
          </div>
          <div class="visualization-editor__section-heading">
            <h4 class="cream-250">${escapeHtml(this.translate('visualizations.sections.preview'))}</h4>
          </div>
          <div data-query-editor-preview-host></div>
        </section>

        <section class="visualization-editor__section" ${this.readOnlyValue ? 'aria-disabled="true"' : ''}>
          <h4 class="cream-250">${escapeHtml(this.translate('visualizations.sections.data'))}</h4>
          ${chartDataFieldsMarkup({
            chartType: draft.chart_type,
            columns,
            dataConfig,
            disabled: this.readOnlyValue,
            t: this.i18n.visualizations.form
          })}
        </section>

        <section class="visualization-editor__section">
          <h4 class="cream-250">${escapeHtml(this.translate('visualizations.sections.appearance'))}</h4>
          <div>
            <label class="label block">${escapeHtml(this.translate('visualizations.form.theme'))}</label>
            <div class="select">
              <select data-scope="root" data-key="theme_reference" data-action="change->query-editor#changeVisualizationField" ${this.readOnlyValue ? 'disabled' : ''}>
                ${themeOptions}
              </select>
              <i class="ri-arrow-drop-down-line"></i>
            </div>
          </div>
          <div class="split">
            ${textFieldMarkup(this.translate('visualizations.form.title'), 'other_config', 'title', otherConfig.title, this.readOnlyValue)}
            ${textFieldMarkup(this.translate('visualizations.form.subtitle'), 'other_config', 'subtitle', otherConfig.subtitle, this.readOnlyValue)}
          </div>
          ${cartesianMarkup({
            chartType: draft.chart_type,
            xAxisLabel: otherConfig.x_axis_label,
            yAxisLabel: otherConfig.y_axis_label,
            disabled: this.readOnlyValue,
            t: this.i18n.visualizations.form
          })}
          ${draft.chart_type === 'donut'
            ? singleTextFieldMarkup(this.translate('visualizations.form.donut_inner_radius'), 'other_config', 'donut_inner_radius', otherConfig.donut_inner_radius, this.readOnlyValue, '58%')
            : ''}
          ${draft.chart_type === 'total'
            ? singleTextFieldMarkup(this.translate('visualizations.form.total_label'), 'other_config', 'total_label', otherConfig.total_label, this.readOnlyValue)
            : ''}
          <div class="split">
            ${booleanSelectMarkup(this.translate('visualizations.form.legend_enabled'), 'other_config', 'legend_enabled', otherConfig.legend_enabled, this.readOnlyValue, this.i18n.common)}
            ${booleanSelectMarkup(this.translate('visualizations.form.tooltip_enabled'), 'other_config', 'tooltip_enabled', otherConfig.tooltip_enabled, this.readOnlyValue, this.i18n.common)}
          </div>
          <div class="visualization-editor__mode-grid">
            ${this.modeEditorMarkup('dark', draft.appearance_editor_dark, draft.appearance_raw_json_dark)}
            ${this.modeEditorMarkup('light', draft.appearance_editor_light, draft.appearance_raw_json_light)}
          </div>
        </section>

        <section class="visualization-editor__section">
          <h4 class="cream-250">${escapeHtml(this.translate('visualizations.sections.sharing'))}</h4>
          <div class="message">
            <i class="ri-information-line ri-lg red-500"></i>
            <div class="body">
              <p class="title cream-250">${escapeHtml(this.translate('visualizations.sharing.title'))}</p>
              <p>${escapeHtml(this.translate('visualizations.sharing.body'))}</p>
            </div>
          </div>
        </section>

        <section class="visualization-editor__section">
          <h4 class="cream-250">${escapeHtml(this.translate('visualizations.sections.other'))}</h4>
          <p class="gray-300">${escapeHtml(this.translate('visualizations.other.description'))}</p>
        </section>
      </div>
    `;
  }

  private modeEditorMarkup(mode: 'dark' | 'light', editorValues: Record<string, string>, rawJson: string): string {
    const labelKey = mode === 'dark' ? 'dark_mode' : 'light_mode';

    return `
      <div class="visualization-editor__mode-card">
        <h5 class="cream-250">${escapeHtml(this.translate(`visualizations.form.${labelKey}`))}</h5>
        <div class="split">
          ${textFieldMarkup(this.translate('visualizations.form.palette'), 'appearance_editor', 'colors_csv', editorValues.colors_csv, this.readOnlyValue, '#F5807B, #5CA1F2', mode)}
          ${textFieldMarkup(this.translate('visualizations.form.background_color'), 'appearance_editor', 'background_color', editorValues.background_color, this.readOnlyValue, '#1C1C1C', mode)}
        </div>
        <div class="split">
          ${textFieldMarkup(this.translate('visualizations.form.text_color'), 'appearance_editor', 'text_color', editorValues.text_color, this.readOnlyValue, '#ECEAE6', mode)}
          ${textFieldMarkup(this.translate('visualizations.form.legend_text_color'), 'appearance_editor', 'legend_text_color', editorValues.legend_text_color, this.readOnlyValue, '#BBBBBB', mode)}
        </div>
        <div class="split">
          ${textFieldMarkup(this.translate('visualizations.form.title_color'), 'appearance_editor', 'title_color', editorValues.title_color, this.readOnlyValue, '', mode)}
          ${textFieldMarkup(this.translate('visualizations.form.subtitle_color'), 'appearance_editor', 'subtitle_color', editorValues.subtitle_color, this.readOnlyValue, '', mode)}
        </div>
        <div class="split">
          ${textFieldMarkup(this.translate('visualizations.form.axis_line_color'), 'appearance_editor', 'axis_line_color', editorValues.axis_line_color, this.readOnlyValue, '#505050', mode)}
          ${textFieldMarkup(this.translate('visualizations.form.axis_label_color'), 'appearance_editor', 'axis_label_color', editorValues.axis_label_color, this.readOnlyValue, '', mode)}
        </div>
        <div class="split">
          ${textFieldMarkup(this.translate('visualizations.form.split_line_color'), 'appearance_editor', 'split_line_color', editorValues.split_line_color, this.readOnlyValue, '#333333', mode)}
          ${textFieldMarkup(this.translate('visualizations.form.tooltip_background_color'), 'appearance_editor', 'tooltip_background_color', editorValues.tooltip_background_color, this.readOnlyValue, '', mode)}
        </div>
        ${singleTextFieldMarkup(this.translate('visualizations.form.tooltip_text_color'), 'appearance_editor', 'tooltip_text_color', editorValues.tooltip_text_color, this.readOnlyValue, '', mode)}
        <label class="label block">${escapeHtml(this.translate('visualizations.form.raw_json'))}</label>
        <textarea class="input block fluid visualization-editor__json"
                  rows="10"
                  data-scope="appearance_raw_json"
                  data-mode="${mode}"
                  data-key="raw_json"
                  data-action="input->query-editor#changeVisualizationField"
                  ${this.readOnlyValue ? 'readonly' : ''}>${escapeHtml(rawJson || '')}</textarea>
      </div>
    `;
  }

  private visualizationPreviewMarkup(draft: VisualizationDraft): string {
    if (!this.result) {
      return `<p class="gray-300">${escapeHtml(this.translate('results.empty'))}</p>`;
    }

    if (this.result.error) {
      return `<p class="red-500">${escapeHtml(this.result.error_message || '')}</p>`;
    }

    const columns = this.result.columns || [];
    const dataConfig = resolvedDataConfig(draft, columns);
    const otherConfig = resolvedOtherConfig(draft, columns);

    if (draft.chart_type === 'table') {
      const pageSize = Number(dataConfig.table_page_size || 10);
      return queryResultsTableMarkup(this.result, pageSize);
    }

    if (draft.chart_type === 'total') {
      const totalValue = totalVisualizationValue(this.result, String(dataConfig.value_key || ''));
      return `
        <div class="visualization-preview-total">
          <div class="visualization-preview-total__value">${escapeHtml(totalValue)}</div>
          ${otherConfig.total_label ? `<div class="visualization-preview-total__label">${escapeHtml(String(otherConfig.total_label))}</div>` : ''}
        </div>
      `;
    }

    const darkTheme = resolveTheme(this.themeLibrary(), draft, 'dark');
    const lightTheme = resolveTheme(this.themeLibrary(), draft, 'light');
    const darkOption = buildOption({
      chartType: draft.chart_type,
      result: this.result,
      dataConfig,
      otherConfig,
      theme: darkTheme
    });
    const lightOption = buildOption({
      chartType: draft.chart_type,
      result: this.result,
      dataConfig,
      otherConfig,
      theme: lightTheme
    });

    return `
      <div
        class="visualization-preview-chart"
        data-controller="echarts-visualization"
        data-echarts-visualization-dark-option-value="${escapeAttribute(JSON.stringify(darkOption))}"
        data-echarts-visualization-light-option-value="${escapeAttribute(JSON.stringify(lightOption))}"
        data-echarts-visualization-dark-theme-value="${escapeAttribute(JSON.stringify(darkTheme))}"
        data-echarts-visualization-light-theme-value="${escapeAttribute(JSON.stringify(lightTheme))}"></div>
    `;
  }

  private availableVisualizationTypes(): VisualizationType[] {
    return this.bootstrap.available_visualization_types;
  }

  private themeLibrary(): ThemeEntry[] {
    return this.bootstrap.theme_library;
  }

  private currentVisualizationDraft(): VisualizationDraft | null {
    if (!this.activeVisualizationType) return null;

    return this.visualizations[this.activeVisualizationType] || null;
  }

  private defaultThemeReference(): string {
    return this.themeLibrary().find((theme) => theme.default)?.reference_key
      || this.themeLibrary()[0]?.reference_key
      || 'system.default_theming';
  }

  private queryTitle(): string {
    return this.query.name?.trim() || this.translate('query.untitled_title');
  }

  private renderQueryLibraryVisibility(): void {
    const searchTerm = this.inputTarget.value.replace('/', '').toLowerCase();

    this.queryLibraryTarget.querySelectorAll<HTMLElement>('.link').forEach((link) => {
      link.classList.add('hide');
      if (link.textContent?.trim().toLowerCase().includes(searchTerm)) {
        link.classList.remove('hide');
      }
    });

    if (this.inputTarget.value.startsWith('/')) {
      this.queryLibraryTarget.classList.add('show');
    } else {
      this.queryLibraryTarget.classList.remove('show');
    }
  }

  private updateTextareaRows(): void {
    this.inputTarget.rows = Math.max(1, (this.inputTarget.value || '').split('\n').length);
  }

  private syncSchemaTable(selectedValue: string): void {
    this.element.querySelectorAll<HTMLTableElement>('.schema-table table').forEach((table) => {
      table.classList.toggle('hide', !table.classList.contains(`schema-table-${selectedValue}`));
    });
  }

  private syncSourceSettingsLink(): void {
    if (!this.dataSourceSettingsLinkTarget) return;

    this.dataSourceSettingsLinkTarget.href = this.dataSourceSettingsBaseUrlValue.replace(
      '__DATA_SOURCE_ID__',
      String(this.currentDataSourceId())
    );
  }

  private baseQueryUrl(dataSourceId: string): string {
    return this.queryBaseUrlValue.replace('__DATA_SOURCE_ID__', dataSourceId);
  }

  private currentDataSourceId(): number {
    const selectedId = Number.parseInt(this.dataSourceSelectTarget.value || '', 10);
    return Number.isFinite(selectedId) && selectedId > 0 ? selectedId : this.query.data_source_id;
  }

  private runEnabled(): boolean {
    return !this.readOnlyValue && Boolean(normalizeSql(this.query.sql));
  }

  private saveEnabled(): boolean {
    if (this.readOnlyValue) return false;
    if (!normalizeSql(this.query.sql)) return false;

    if (!this.query.saved) {
      return Boolean(this.runToken && this.currentFingerprint() === this.lastSuccessfulFingerprint && this.result && !this.result.error);
    }

    const dirtyCount = this.dirtyCount();
    if (dirtyCount === 0) return false;
    if (this.querySurfaceDirty()) {
      return Boolean(this.runToken && this.currentFingerprint() === this.lastSuccessfulFingerprint && this.result && !this.result.error);
    }

    return true;
  }

  private dirtyCount(): number {
    if (!this.query.saved) return 0;

    let count = 0;
    if (this.querySurfaceDirty()) count += 1;
    if (this.settingsDirty()) count += 1;
    count += this.dirtyVisualizationTypes().length;
    return count;
  }

  private querySurfaceDirty(): boolean {
    return this.currentDataSourceId() !== this.baselineQuery.data_source_id || normalizeSql(this.query.sql) !== normalizeSql(this.baselineQuery.sql);
  }

  private settingsDirty(): boolean {
    return (this.query.name || '').trim() !== (this.baselineQuery.name || '').trim();
  }

  private dirtyVisualizationTypes(): string[] {
    const currentTypes = Object.keys(this.visualizations);
    const baselineTypes = Object.keys(this.baselineVisualizations);
    const types = Array.from(new Set([...currentTypes, ...baselineTypes]));

    return types.filter((chartType) => !deepEqual(this.visualizations[chartType] || null, this.baselineVisualizations[chartType] || null));
  }

  private currentFingerprint(): string | null {
    return fingerprintFor(this.currentDataSourceId(), this.query.sql);
  }

  private syncResultForCurrentSql(): void {
    if (this.currentFingerprint() && this.currentFingerprint() === this.lastSuccessfulFingerprint) {
      this.result = deepClone(this.lastSuccessfulResult);
      this.runToken = this.runToken;
      return;
    }

    this.result = null;
  }

  private snapshotQuery(): QueryPayload {
    return {
      id: this.query.id,
      saved: this.query.saved,
      name: this.query.name,
      sql: this.query.sql,
      data_source_id: this.currentDataSourceId(),
      canonical_path: this.query.canonical_path
    };
  }

  private snapshotVisualizations(): Record<string, VisualizationDraft> {
    return deepClone(this.visualizations);
  }

  private visualizationPayloadsForSave(): Array<Record<string, unknown>> {
    return this.availableVisualizationTypes()
      .map((type) => this.visualizations[type.chart_type])
      .filter((draft): draft is VisualizationDraft => Boolean(draft))
      .map((draft) => ({
        chart_type: draft.chart_type,
        theme_reference: draft.theme_reference,
        data_config: draft.data_config,
        other_config: draft.other_config,
        appearance_editor_dark: draft.appearance_editor_dark,
        appearance_editor_light: draft.appearance_editor_light,
        appearance_raw_json_dark: draft.appearance_raw_json_dark,
        appearance_raw_json_light: draft.appearance_raw_json_light
      }));
  }

  private indexVisualizations(visualizations: VisualizationDraft[]): Record<string, VisualizationDraft> {
    return visualizations.reduce<Record<string, VisualizationDraft>>((memo, visualization) => {
      memo[visualization.chart_type] = visualization;
      return memo;
    }, {});
  }

  private translate(path: string): string {
    return path.split('.').reduce<any>((memo, key) => memo?.[key], this.i18n) || '';
  }

  private persistTabParam(): void {
    const url = new URL(window.location.href);
    url.searchParams.set('tab', this.activeTab);
    window.history.replaceState({}, '', `${url.pathname}?${url.searchParams.toString()}`);
  }

  private requestJson(path: string, payload: Record<string, unknown>): Promise<any> {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';

    return fetch(path, {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify(payload)
    }).then(async (response) => {
      const raw = await response.text();
      const data = raw ? JSON.parse(raw) : {};
      if (!response.ok) throw new Error(data.message || '');
      return data;
    });
  }

  private parseJsonTarget<T>(target: HTMLScriptElement): T {
    return JSON.parse(target.textContent || '{}') as T;
  }

  private turboVisit(path: string): void {
    const turbo = (window as Window & { Turbo?: { visit: (location: string, options?: { action?: string }) => void } }).Turbo;
    if (turbo) {
      turbo.visit(path, { action: 'replace' });
      return;
    }

    window.location.assign(path);
  }

  private persistPendingToast(toast: Record<string, string>): void {
    window.sessionStorage.setItem('query-editor-pending-toast', JSON.stringify(toast));
  }

  private restorePendingToast(): void {
    const value = window.sessionStorage.getItem('query-editor-pending-toast');
    if (!value) return;

    window.sessionStorage.removeItem('query-editor-pending-toast');
    try {
      const toast = JSON.parse(value);
      this.showToast(toast.type || 'information', toast.title || '', toast.body || '');
    } catch (_error) {
      // Ignore invalid session payloads.
    }
  }

  private showToast(type: 'success' | 'error' | 'information', title: string, body: string): void {
    let stack = document.querySelector('.toast-stack');
    if (!(stack instanceof HTMLElement)) {
      stack = document.createElement('div');
      stack.className = 'toast-stack';
      stack.dataset.controller = 'toast-stack';

      const insertionTarget = document.querySelector('.app-content-layout') || document.body.firstElementChild;
      insertionTarget?.parentElement?.insertBefore(stack, insertionTarget);
    }

    const iconClass = type === 'success'
      ? 'ri-checkbox-circle-line'
      : type === 'error'
        ? 'ri-error-warning-line'
        : 'ri-information-line';

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.dataset.toastStackTarget = 'toast';
    if (type === 'success') toast.dataset.autoDismissMs = '5000';
    toast.innerHTML = `
      <div class="toast-head">
        <div class="toast-title-wrap">
          <i class="toast-icon ${iconClass}"></i>
          <p class="toast-title">${escapeHtml(title)}</p>
        </div>
        <button type="button" class="toast-close" aria-label="${escapeAttribute(this.translate('common.close'))}" data-action="click->toast-stack#dismiss">
          <i class="ri-close-line"></i>
        </button>
      </div>
      ${body ? `<p class="toast-body">${escapeHtml(body)}</p>` : ''}
    `;

    stack.appendChild(toast);
  }
}

function normalizeSql(value: string | null | undefined): string | null {
  const normalized = (value || '').trim().replace(/;\s*$/, '').replace(/\s+/g, ' ').trim();
  return normalized || null;
}

function fingerprintFor(dataSourceId: number, sql: string | null | undefined): string | null {
  const normalizedSql = normalizeSql(sql);
  if (!dataSourceId || !normalizedSql) return null;

  return `${dataSourceId}:${normalizedSql}`;
}

function deepClone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value));
}

function deepEqual(left: unknown, right: unknown): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function escapeAttribute(value: string): string {
  return escapeHtml(value);
}

function optionMarkup(value: string, label: string, selectedValue: string): string {
  return `<option value="${escapeAttribute(value)}" ${value === selectedValue ? 'selected' : ''}>${escapeHtml(label)}</option>`;
}

function normalizeFieldValue(value: string): string | boolean {
  if (value === 'true') return true;
  if (value === 'false') return false;
  return value;
}

function buildDefaultVisualizationDraft({
  chartType,
  themeReference,
  columns,
  visualizationTypes
}: {
  chartType: string;
  themeReference: string;
  columns: string[];
  visualizationTypes: VisualizationType[];
}): VisualizationDraft {
  const renderer = visualizationTypes.find((item) => item.chart_type === chartType)?.renderer || 'echarts';
  const appearanceEditorDark = themeEditorAttributes({});
  const appearanceEditorLight = themeEditorAttributes({});

  return {
    chart_type: chartType,
    theme_reference: themeReference,
    renderer,
    data_config: visualizationDefaultsData(chartType, columns),
    other_config: visualizationDefaultsOther(chartType, columns),
    appearance_config_dark: {},
    appearance_config_light: {},
    appearance_editor_dark: appearanceEditorDark,
    appearance_editor_light: appearanceEditorLight,
    appearance_raw_json_dark: '{}',
    appearance_raw_json_light: '{}'
  };
}

function visualizationDefaultsData(chartType: string, columns: string[]): Record<string, unknown> {
  const first = columns[0];
  const second = columns[1] || first;
  const last = columns[columns.length - 1] || second || first;

  const payload: Record<string, unknown> = {
    dimension_key: first,
    value_key: last,
    table_page_size: 10
  };

  if (chartType === 'pie' || chartType === 'donut') {
    payload.dimension_key = first;
    payload.value_key = second || last || first;
  }

  if (chartType === 'total') {
    payload.value_key = first;
  }

  return payload;
}

function visualizationDefaultsOther(chartType: string, columns: string[]): Record<string, unknown> {
  const first = columns[0];
  const last = columns[columns.length - 1] || first;

  return {
    title: '',
    subtitle: '',
    title_enabled: false,
    subtitle_enabled: false,
    legend_enabled: chartType === 'pie' || chartType === 'donut',
    tooltip_enabled: true,
    x_axis_label: first ? humanize(first) : '',
    x_axis_label_enabled: ['line', 'area', 'column', 'bar'].includes(chartType),
    y_axis_label: last ? humanize(last) : '',
    y_axis_label_enabled: ['line', 'area', 'column', 'bar'].includes(chartType),
    total_label: '',
    total_label_enabled: false,
    donut_inner_radius: '58%'
  };
}

function resolvedDataConfig(draft: VisualizationDraft, columns: string[]): Record<string, any> {
  return { ...visualizationDefaultsData(draft.chart_type, columns), ...draft.data_config };
}

function resolvedOtherConfig(draft: VisualizationDraft, columns: string[]): Record<string, any> {
  return { ...visualizationDefaultsOther(draft.chart_type, columns), ...draft.other_config };
}

function themeEditorAttributes(themeJson: Record<string, unknown>): Record<string, string> {
  const payload = themeJson || {};

  return {
    colors_csv: Array((payload.color as string[]) || []).join(', '),
    background_color: String(payload.backgroundColor || ''),
    text_color: String(dig(payload, ['textStyle', 'color']) || ''),
    title_color: String(dig(payload, ['title', 'textStyle', 'color']) || ''),
    subtitle_color: String(dig(payload, ['title', 'subtextStyle', 'color']) || ''),
    legend_text_color: String(dig(payload, ['legend', 'textStyle', 'color']) || ''),
    axis_line_color: String(dig(payload, ['categoryAxis', 'axisLine', 'lineStyle', 'color']) || dig(payload, ['valueAxis', 'axisLine', 'lineStyle', 'color']) || ''),
    axis_label_color: String(dig(payload, ['categoryAxis', 'axisLabel', 'color']) || dig(payload, ['valueAxis', 'axisLabel', 'color']) || ''),
    split_line_color: String(dig(payload, ['categoryAxis', 'splitLine', 'lineStyle', 'color']) || dig(payload, ['valueAxis', 'splitLine', 'lineStyle', 'color']) || ''),
    tooltip_background_color: String(dig(payload, ['tooltip', 'backgroundColor']) || ''),
    tooltip_text_color: String(dig(payload, ['tooltip', 'textStyle', 'color']) || '')
  };
}

function resolveAppearanceConfig(draft: VisualizationDraft, mode: 'dark' | 'light'): Record<string, unknown> {
  const rawJson = mode === 'dark' ? draft.appearance_raw_json_dark : draft.appearance_raw_json_light;
  const parsedJson = parseJson(rawJson);
  if (parsedJson) return parsedJson;

  const base = deepClone(mode === 'dark' ? draft.appearance_config_dark : draft.appearance_config_light);
  const editorValues = mode === 'dark' ? draft.appearance_editor_dark : draft.appearance_editor_light;

  applyEditorValue(base, ['color'], editorValues.colors_csv ? editorValues.colors_csv.split(',').map((item) => item.trim()).filter(Boolean) : undefined);
  applyEditorValue(base, ['backgroundColor'], editorValues.background_color);
  applyEditorValue(base, ['textStyle', 'color'], editorValues.text_color);
  applyEditorValue(base, ['title', 'textStyle', 'color'], editorValues.title_color);
  applyEditorValue(base, ['title', 'subtextStyle', 'color'], editorValues.subtitle_color);
  applyEditorValue(base, ['legend', 'textStyle', 'color'], editorValues.legend_text_color);
  applyEditorValue(base, ['categoryAxis', 'axisLine', 'lineStyle', 'color'], editorValues.axis_line_color);
  applyEditorValue(base, ['valueAxis', 'axisLine', 'lineStyle', 'color'], editorValues.axis_line_color);
  applyEditorValue(base, ['categoryAxis', 'axisLabel', 'color'], editorValues.axis_label_color);
  applyEditorValue(base, ['valueAxis', 'axisLabel', 'color'], editorValues.axis_label_color);
  applyEditorValue(base, ['categoryAxis', 'splitLine', 'lineStyle', 'color'], editorValues.split_line_color);
  applyEditorValue(base, ['valueAxis', 'splitLine', 'lineStyle', 'color'], editorValues.split_line_color);
  applyEditorValue(base, ['tooltip', 'backgroundColor'], editorValues.tooltip_background_color);
  applyEditorValue(base, ['tooltip', 'textStyle', 'color'], editorValues.tooltip_text_color);

  return base;
}

function applyEditorValue(payload: Record<string, unknown>, path: string[], value: unknown): void {
  if (value === undefined || value === null || value === '') return;

  let cursor: Record<string, any> = payload;
  path.slice(0, -1).forEach((segment) => {
    cursor[segment] = cursor[segment] || {};
    cursor = cursor[segment];
  });
  cursor[path[path.length - 1]] = value;
}

function parseJson(value: string): Record<string, unknown> | null {
  const normalized = value.trim();
  if (!normalized) return null;

  try {
    return JSON.parse(normalized) as Record<string, unknown>;
  } catch (_error) {
    return null;
  }
}

function resolveTheme(themeLibrary: ThemeEntry[], draft: VisualizationDraft, mode: 'dark' | 'light'): Record<string, unknown> {
  const theme = themeLibrary.find((entry) => entry.reference_key === draft.theme_reference);
  const baseTheme = deepClone(mode === 'dark' ? theme?.theme_json_dark || {} : theme?.theme_json_light || {});
  const overrides = resolveAppearanceConfig(draft, mode);
  return deepMerge(baseTheme, overrides);
}

function buildOption({
  chartType,
  result,
  dataConfig,
  otherConfig,
  theme
}: {
  chartType: string;
  result: NonNullable<QueryResultPayload>;
  dataConfig: Record<string, any>;
  otherConfig: Record<string, any>;
  theme: Record<string, any>;
}): Record<string, unknown> | null {
  if (!['line', 'area', 'column', 'bar', 'pie', 'donut'].includes(chartType)) return null;

  const cartesianChart = ['line', 'area', 'column', 'bar'].includes(chartType);
  const pieLikeChart = ['pie', 'donut'].includes(chartType);
  const horizontalBarChart = chartType === 'bar';

  const option: Record<string, any> = {
    backgroundColor: theme.backgroundColor,
    color: theme.color,
    textStyle: theme.textStyle,
    animationDuration: 250,
    tooltip: {
      show: Boolean(otherConfig.tooltip_enabled),
      trigger: pieLikeChart ? 'item' : 'axis',
      backgroundColor: dig(theme, ['tooltip', 'backgroundColor']),
      borderColor: dig(theme, ['tooltip', 'borderColor']),
      textStyle: dig(theme, ['tooltip', 'textStyle'])
    },
    legend: {
      show: Boolean(otherConfig.legend_enabled),
      textStyle: dig(theme, ['legend', 'textStyle'])
    },
    title: {
      show: Boolean(otherConfig.title_enabled) || Boolean(otherConfig.title) || Boolean(otherConfig.subtitle_enabled) || Boolean(otherConfig.subtitle),
      text: Boolean(otherConfig.title_enabled) ? String(otherConfig.title || '') : '',
      subtext: Boolean(otherConfig.subtitle_enabled) ? String(otherConfig.subtitle || '') : '',
      left: 'center',
      textStyle: dig(theme, ['title', 'textStyle']),
      subtextStyle: dig(theme, ['title', 'subtextStyle'])
    },
    dataset: {
      source: [result.columns, ...result.rows]
    }
  };

  if (cartesianChart) {
    option.grid = {
      left: 24,
      right: 24,
      top: titleSpacing(otherConfig),
      bottom: 36,
      containLabel: true
    };
    option.xAxis = {
      type: horizontalBarChart ? 'value' : 'category',
      name: axisName(otherConfig.x_axis_label_enabled, otherConfig.x_axis_label),
      nameLocation: 'middle',
      nameGap: 28,
      axisLine: horizontalBarChart ? dig(theme, ['valueAxis', 'axisLine']) : dig(theme, ['categoryAxis', 'axisLine']),
      axisLabel: horizontalBarChart ? dig(theme, ['valueAxis', 'axisLabel']) : dig(theme, ['categoryAxis', 'axisLabel']),
      splitLine: horizontalBarChart ? dig(theme, ['valueAxis', 'splitLine']) : dig(theme, ['categoryAxis', 'splitLine'])
    };
    option.yAxis = {
      type: horizontalBarChart ? 'category' : 'value',
      name: axisName(otherConfig.y_axis_label_enabled, otherConfig.y_axis_label),
      nameLocation: 'middle',
      nameGap: horizontalBarChart ? 52 : 48,
      axisLine: horizontalBarChart ? dig(theme, ['categoryAxis', 'axisLine']) : dig(theme, ['valueAxis', 'axisLine']),
      axisLabel: horizontalBarChart ? dig(theme, ['categoryAxis', 'axisLabel']) : dig(theme, ['valueAxis', 'axisLabel']),
      splitLine: horizontalBarChart ? dig(theme, ['categoryAxis', 'splitLine']) : dig(theme, ['valueAxis', 'splitLine'])
    };
  }

  if (pieLikeChart) {
    option.series = [{
      type: 'pie',
      radius: chartType === 'donut' ? [otherConfig.donut_inner_radius || '58%', '78%'] : '78%',
      encode: {
        itemName: dataConfig.dimension_key,
        value: dataConfig.value_key
      }
    }];
    return option;
  }

  option.series = [{
    type: chartType === 'column' ? 'bar' : chartType === 'bar' ? 'bar' : 'line',
    smooth: chartType === 'line' || chartType === 'area',
    areaStyle: chartType === 'area' ? {} : undefined,
    encode: horizontalBarChart
      ? { x: dataConfig.value_key, y: dataConfig.dimension_key }
      : { x: dataConfig.dimension_key, y: dataConfig.value_key },
    showSymbol: chartType !== 'area'
  }];

  return option;
}

function titleSpacing(otherConfig: Record<string, any>): number {
  const hasTitle = Boolean(otherConfig.title_enabled) || Boolean(otherConfig.title);
  const hasSubtitle = Boolean(otherConfig.subtitle_enabled) || Boolean(otherConfig.subtitle);
  if (hasTitle && hasSubtitle) return 88;
  if (hasTitle || hasSubtitle) return 64;
  return 24;
}

function axisName(enabled: unknown, label: unknown): string | null {
  if (!enabled) return null;
  const normalized = String(label || '').trim();
  return normalized || null;
}

function dig(payload: Record<string, any>, path: string[]): unknown {
  return path.reduce<any>((memo, key) => memo?.[key], payload);
}

function deepMerge(left: Record<string, any>, right: Record<string, any>): Record<string, any> {
  const result = deepClone(left);
  Object.entries(right || {}).forEach(([key, value]) => {
    if (value && typeof value === 'object' && !Array.isArray(value) && result[key] && typeof result[key] === 'object' && !Array.isArray(result[key])) {
      result[key] = deepMerge(result[key], value as Record<string, any>);
      return;
    }

    result[key] = value;
  });
  return result;
}

function queryResultsTableMarkup(result: NonNullable<QueryResultPayload>, pageSize: number): string {
  const headers = result.columns.map((column) => `<th>${escapeHtml(String(column))}</th>`).join('');
  const rows = result.rows.map((row) => `
    <tr>
      ${result.columns.map((_, index) => {
        const value = row[index];
        return `<td>${value === null || value === undefined || value === '' ? '<span class="null">NULL</span>' : escapeHtml(String(value))}</td>`;
      }).join('')}
    </tr>
  `).join('');

  return `
    <div class="query-results"
         data-controller="query-results-table"
         data-query-results-table-page-size-value="${pageSize}"
         data-query-results-table-result-value="${escapeAttribute(JSON.stringify(result.rows))}">
      <div class="query-results-table">
        <table>
          <tr>${headers}</tr>
          ${rows}
        </table>
      </div>
      <div class="pagination ${result.rows.length <= pageSize ? 'hidden' : ''}">
        <button type="button" class="link disabled" data-query-results-table-target="start" data-action="query-results-table#start">
          <i class="ri-arrow-left-double-line gray-500"></i>
        </button>
        <button type="button" class="link disabled" data-query-results-table-target="prev" data-action="query-results-table#prev">
          <i class="ri-arrow-left-s-line gray-500"></i>
        </button>
        <div class="page">
          <span class="current-page" data-query-results-table-target="currentPage">0</span> <span class="gray-500">of</span> <span class="total-pages" data-query-results-table-target="totalPages">0</span>
        </div>
        <button type="button" class="link" data-query-results-table-target="next" data-action="query-results-table#next">
          <i class="ri-arrow-right-s-line gray-500"></i>
        </button>
        <button type="button" class="link" data-query-results-table-target="end" data-action="query-results-table#end">
          <i class="ri-arrow-right-double-line gray-500"></i>
        </button>
      </div>
    </div>
  `;
}

function textFieldMarkup(
  label: string,
  scope: string,
  key: string,
  value: unknown,
  disabled: boolean,
  placeholder = '',
  mode?: string
): string {
  return `
    <div>
      <label class="label block">${escapeHtml(label)}</label>
      <input
        type="text"
        class="input block fluid"
        value="${escapeAttribute(String(value || ''))}"
        placeholder="${escapeAttribute(placeholder)}"
        data-scope="${scope}"
        data-key="${key}"
        ${mode ? `data-mode="${mode}"` : ''}
        data-action="input->query-editor#changeVisualizationField"
        ${disabled ? 'readonly' : ''}>
    </div>
  `;
}

function singleTextFieldMarkup(
  label: string,
  scope: string,
  key: string,
  value: unknown,
  disabled: boolean,
  placeholder = '',
  mode?: string
): string {
  return textFieldMarkup(label, scope, key, value, disabled, placeholder, mode);
}

function booleanSelectMarkup(
  label: string,
  scope: string,
  key: string,
  value: unknown,
  disabled: boolean,
  commonTranslations: { enabled: string; disabled: string }
): string {
  return `
    <div>
      <label class="label block">${escapeHtml(label)}</label>
      <div class="select">
        <select data-scope="${scope}" data-key="${key}" data-action="change->query-editor#changeVisualizationField" ${disabled ? 'disabled' : ''}>
          ${optionMarkup('true', commonTranslations.enabled, String(Boolean(value)))}
          ${optionMarkup('false', commonTranslations.disabled, String(Boolean(value)))}
        </select>
        <i class="ri-arrow-drop-down-line"></i>
      </div>
    </div>
  `;
}

function chartDataFieldsMarkup({
  chartType,
  columns,
  dataConfig,
  disabled,
  t
}: {
  chartType: string;
  columns: string[];
  dataConfig: Record<string, any>;
  disabled: boolean;
  t: Record<string, string>;
}): string {
  const dimensionSelect = `
    <div>
      <label class="label block">${escapeHtml(t.dimension_key)}</label>
      <div class="select">
        <select data-scope="data_config" data-key="dimension_key" data-action="change->query-editor#changeVisualizationField" ${disabled ? 'disabled' : ''}>
          ${columns.map((column) => optionMarkup(column, column, String(dataConfig.dimension_key || ''))).join('')}
        </select>
        <i class="ri-arrow-drop-down-line"></i>
      </div>
    </div>
  `;
  const valueSelect = `
    <div>
      <label class="label block">${escapeHtml(t.value_key)}</label>
      <div class="select">
        <select data-scope="data_config" data-key="value_key" data-action="change->query-editor#changeVisualizationField" ${disabled ? 'disabled' : ''}>
          ${columns.map((column) => optionMarkup(column, column, String(dataConfig.value_key || ''))).join('')}
        </select>
        <i class="ri-arrow-drop-down-line"></i>
      </div>
    </div>
  `;

  if (['line', 'area', 'column', 'bar'].includes(chartType)) {
    return `<div class="split">${dimensionSelect}${valueSelect}</div>`;
  }

  if (chartType === 'pie' || chartType === 'donut') {
    return `<div class="split">${dimensionSelect}${valueSelect}</div>`;
  }

  if (chartType === 'total') {
    return `<div class="split">${valueSelect}</div>`;
  }

  if (chartType === 'table') {
    return `
      <div>
        <label class="label block">${escapeHtml(t.table_page_size)}</label>
        <div class="select">
          <select data-scope="data_config" data-key="table_page_size" data-action="change->query-editor#changeVisualizationField" ${disabled ? 'disabled' : ''}>
            ${[10, 25, 50, 100].map((size) => optionMarkup(String(size), String(size), String(dataConfig.table_page_size || '10'))).join('')}
          </select>
          <i class="ri-arrow-drop-down-line"></i>
        </div>
      </div>
    `;
  }

  return '';
}

function cartesianMarkup({
  chartType,
  xAxisLabel,
  yAxisLabel,
  disabled,
  t
}: {
  chartType: string;
  xAxisLabel: unknown;
  yAxisLabel: unknown;
  disabled: boolean;
  t: Record<string, string>;
}): string {
  if (!['line', 'area', 'column', 'bar'].includes(chartType)) return '';

  return `
    <div class="split">
      ${textFieldMarkup(t.x_axis_label, 'other_config', 'x_axis_label', xAxisLabel, disabled)}
      ${textFieldMarkup(t.y_axis_label, 'other_config', 'y_axis_label', yAxisLabel, disabled)}
    </div>
  `;
}

function totalVisualizationValue(result: NonNullable<QueryResultPayload>, columnName: string): string {
  const index = result.columns.indexOf(columnName);
  if (index < 0) return '0';

  const value = result.rows[0]?.[index];
  return value === null || value === undefined ? '0' : String(value);
}

function humanize(value: string): string {
  return value
    .replaceAll('_', ' ')
    .trim()
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

function interpolate(template: string, values: Record<string, string>): string {
  return Object.entries(values).reduce((memo, [key, value]) => {
    return memo.replaceAll(`%{${key}}`, value);
  }, template);
}
