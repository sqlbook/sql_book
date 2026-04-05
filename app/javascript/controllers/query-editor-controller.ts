import { Controller } from '@hotwired/stimulus';
import type {
  BootstrapPayload,
  QueryEditorTab,
  QueryPayload,
  QueryResultPayload,
  ThemeEntry,
  TranslationPayload,
  VisualizationDraft,
  VisualizationType
} from '../query_editor/types';
import {
  hasGroupName,
  normalizeGroupName,
  resolveExistingGroupName,
  sortGroupNames
} from '../query_editor/groups';
import {
  currentFingerprint,
  dirtyCount,
  indexVisualizations,
  queryTitle,
  runEnabled,
  saveEnabled,
  snapshotQuery,
  snapshotVisualizations,
  visualizationPayloadsForSave
} from '../query_editor/state';
import { renderQuerySettingsPane } from '../query_editor/settings';
import {
  buildDefaultVisualizationDraft,
  defaultThemeReference,
  queryResultsTableMarkup,
  renderVisualizationEditor,
  renderVisualizationGallery,
  renderVisualizationPreview
} from '../query_editor/visualization';
import { JsonRequestError, requestJson, persistPendingToast, restorePendingToast, turboVisit } from '../query_editor/transport';
import { showToast } from '../query_editor/toast';
import { deepClone, escapeAttribute, escapeHtml, interpolate, normalizeFieldValue, translate } from '../query_editor/utils';

const PENDING_TOAST_KEY = 'query-editor-pending-toast';

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
    generateNameUrl: String,
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
  declare readonly generateNameUrlValue: string;
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
  private activeTab: QueryEditorTab = 'query_results';
  private activeVisualizationType: string | null = null;
  private autoRunRequested = false;
  private generatedNameLocked = false;
  private generatedNameAttempted = false;
  private generatedNamePending = false;
  private groupInputValue = '';
  private groupMenuOpen = false;
  private readonly handleDocumentMouseDown = (event: MouseEvent): void => {
    if (!this.groupMenuOpen || this.activeTab !== 'settings') return;

    const target = event.target;
    if (!(target instanceof Node)) return;

    const picker = this.settingsPaneTarget.querySelector('.query-group-picker');
    if (picker && !picker.contains(target)) {
      this.groupMenuOpen = false;
      this.renderSettingsPane();
    }
  };

  connect(): void {
    this.bootstrap = this.parseJsonTarget<BootstrapPayload>(this.bootstrapTarget);
    this.i18n = this.parseJsonTarget<TranslationPayload>(this.translationsTarget);
    this.query = deepClone(this.bootstrap.query);
    this.query.group_names = sortGroupNames(this.query.group_names || []);
    this.result = deepClone(this.bootstrap.result);
    this.runToken = this.bootstrap.run_token || null;
    this.lastSuccessfulFingerprint = this.runToken ? this.currentFingerprint() : null;
    this.lastSuccessfulResult = deepClone(this.bootstrap.result);
    this.visualizations = indexVisualizations(this.bootstrap.visualizations);
    this.baselineQuery = snapshotQuery(this.query, this.currentDataSourceId());
    this.baselineVisualizations = snapshotVisualizations(this.visualizations);
    this.activeTab = this.bootstrap.active_tab || 'query_results';
    this.generatedNameLocked = Boolean(this.query.name);
    this.generatedNameAttempted = Boolean(this.query.saved || this.query.name);

    const pendingToast = restorePendingToast(PENDING_TOAST_KEY);
    if (pendingToast) this.showToast(pendingToast.type, pendingToast.title, pendingToast.body);

    document.addEventListener('mousedown', this.handleDocumentMouseDown);
    this.renderAll();
    this.focusInputOnLoad();
    this.autoRunOnLoad();
  }

  disconnect(): void {
    document.removeEventListener('mousedown', this.handleDocumentMouseDown);
  }

  change(event: Event): void {
    const target = event.target as HTMLTextAreaElement;
    this.query.sql = target.value;
    this.generatedNamePending = false;
    this.syncResultForCurrentSql();
    this.renderQueryLibraryVisibility();
    this.updateTextareaRows();
    this.renderPanelTitle();
    this.renderFooter();
    this.renderResultsPane();
    if (this.activeTab === 'visualization') this.renderVisualizationPane();
  }

  changeSource(event: Event): void {
    const target = event.target as HTMLSelectElement;
    const selectedId = target.value;
    if (!selectedId) return;

    const nextUrl = new URL(this.baseQueryUrl(selectedId), window.location.origin);
    if (this.query.sql?.trim()) nextUrl.searchParams.set('query', this.query.sql);
    if (this.query.name?.trim()) nextUrl.searchParams.set('name', this.query.name);
    nextUrl.searchParams.set('tab', this.activeTab);
    turboVisit(nextUrl.pathname + nextUrl.search);
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
    this.generatedNamePending = false;
    this.syncResultForCurrentSql();
    this.renderQueryLibraryVisibility();
    this.updateTextareaRows();
    this.renderPanelTitle();
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
    const tab = target.dataset.tab as QueryEditorTab | undefined;
    if (!tab) return;

    this.activeTab = tab;
    if (tab !== 'settings') {
      this.groupMenuOpen = false;
      this.groupInputValue = '';
    }
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
        themeReference: defaultThemeReference(this.themeLibrary()),
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
    this.generatedNamePending = false;
    this.renderPanelTitle();
    this.renderFooter();
  }

  focusGroupInput(): void {
    this.groupMenuOpen = this.shouldShowGroupMenu();
    this.renderSettingsPane();
    this.focusGroupInputField();
  }

  changeGroupInput(event: Event): void {
    const target = event.target as HTMLInputElement;
    this.groupInputValue = target.value;
    this.groupMenuOpen = this.shouldShowGroupMenu();
    this.renderSettingsPane();
    this.focusGroupInputField();
  }

  handleGroupInputKeydown(event: KeyboardEvent): void {
    if (event.key === 'Enter') {
      event.preventDefault();
      this.commitGroupInput();
      return;
    }

    if (event.key === 'Escape') {
      event.preventDefault();
      this.groupMenuOpen = false;
      this.renderSettingsPane();
      this.focusGroupInputField();
    }
  }

  selectGroupOption(event: Event): void {
    event.preventDefault();

    const target = event.currentTarget as HTMLElement;
    const groupName = target.dataset.groupName;
    if (groupName) {
      this.addGroupName(groupName);
      return;
    }

    if (target.dataset.createGroup === 'true') this.commitGroupInput();
  }

  removeGroup(event: Event): void {
    const target = event.currentTarget as HTMLElement;
    const groupName = target.dataset.groupName;
    if (!groupName) return;

    this.query.group_names = this.query.group_names.filter((name) => {
      return normalizeGroupName(name).toLocaleLowerCase() !== normalizeGroupName(groupName).toLocaleLowerCase();
    });
    this.renderSettingsPane();
    this.renderFooter();
  }

  runQuery(): void {
    if (!this.runEnabled()) return;

    this.dispatch('open-panel', { bubbles: true });

    requestJson(this.runUrlValue, {
      data_source_id: this.currentDataSourceId(),
      name: this.query.name,
      sql: this.query.sql
    }).then((payload) => {
      const data = payload.data || {};
      this.result = data.result || null;
      this.lastSuccessfulResult = deepClone(this.result);
      this.runToken = data.run_token || null;
      this.lastSuccessfulFingerprint = this.runToken ? this.currentFingerprint() : null;
      this.generatedNamePending = this.shouldGenerateNameAfterRun();

      this.renderAll();
      this.requestGeneratedNameIfNeeded();
    }).catch((error: JsonRequestError) => {
      this.generatedNamePending = false;
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

    requestJson(this.saveUrlValue, {
      query_id: this.query.id,
      data_source_id: this.currentDataSourceId(),
      name: this.query.name,
      sql: this.query.sql,
      run_token: this.runToken,
      group_names: this.query.group_names,
      visualizations: visualizationPayloadsForSave(this.availableVisualizationTypes(), this.visualizations)
    }).then((payload) => {
      const data = payload.data || {};
      const savedQuery = data.query;
      if (!savedQuery) return;

      if (data.save_outcome === 'already_saved' && savedQuery.canonical_path) {
        persistPendingToast(PENDING_TOAST_KEY, {
          type: 'information',
          title: this.translate('toasts.already_saved_title'),
          body: interpolate(this.translate('toasts.already_saved_body'), { name: savedQuery.name || '' })
        });
        turboVisit(savedQuery.canonical_path);
        return;
      }

      this.query.id = savedQuery.id;
      this.query.saved = Boolean(savedQuery.saved);
      this.query.name = savedQuery.name;
      this.query.sql = savedQuery.sql;
      this.query.data_source_id = savedQuery.data_source_id;
      this.query.group_names = sortGroupNames(savedQuery.group_names || []);
      this.query.canonical_path = savedQuery.canonical_path;
      if (Array.isArray(data.available_query_groups)) {
        this.bootstrap.available_query_groups = sortGroupNames(data.available_query_groups);
      }
      if (Array.isArray(savedQuery.visualizations)) {
        this.visualizations = indexVisualizations(savedQuery.visualizations);
        if (this.activeVisualizationType && !this.visualizations[this.activeVisualizationType]) {
          this.activeVisualizationType = null;
        }
      }

      this.baselineQuery = snapshotQuery(this.query, this.currentDataSourceId());
      this.baselineVisualizations = snapshotVisualizations(this.visualizations);

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
    }).catch((error: JsonRequestError) => {
      if (error.code === 'query.name_required') {
        this.activeTab = 'settings';
        this.renderTabs();
        this.renderPaneVisibility();
        this.renderSettingsPane();
        this.showToast(
          'error',
          this.translate('toasts.name_required_title'),
          this.translate('toasts.name_required_body')
        );
        return;
      }

      if (error.code === 'query.run_required') {
        this.showToast(
          'error',
          this.translate('toasts.run_required_title'),
          this.translate('toasts.run_required_body')
        );
        return;
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

  private focusInputOnLoad(): void {
    if (this.readOnlyValue) return;

    window.requestAnimationFrame(() => {
      if (!this.element.isConnected) return;

      const activeElement = document.activeElement;
      const canStealFocus = !activeElement || activeElement === document.body || activeElement === this.inputTarget;
      if (!canStealFocus) return;

      this.inputTarget.focus({ preventScroll: true });
      const length = this.inputTarget.value.length;
      this.inputTarget.setSelectionRange(length, length);
    });
  }

  private autoRunOnLoad(): void {
    if (this.autoRunRequested || !this.shouldAutoRunOnLoad()) return;

    this.autoRunRequested = true;

    window.requestAnimationFrame(() => {
      if (!this.element.isConnected) return;
      this.runQuery();
    });
  }

  private renderPanelTitle(): void {
    const pending = this.generatedNamePending && !this.query.name?.trim();
    this.panelTitleTarget.classList.toggle('tabbed-side-panel__title--pending', pending);
    this.panelTitleTarget.textContent = pending
      ? this.translate('query.generating_name')
      : queryTitle(this.query, this.translate('query.untitled_title'));
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
      const draft = this.currentVisualizationDraft();
      if (!draft) {
        this.activeVisualizationType = null;
        this.renderVisualizationPane();
        return;
      }

      this.visualizationPaneTarget.innerHTML = renderVisualizationEditor({
        draft,
        columns: this.result?.columns || [],
        readOnly: this.readOnlyValue,
        themeLibrary: this.themeLibrary(),
        i18n: this.i18n
      });
      this.renderVisualizationPreviewOnly();
      return;
    }

    this.visualizationPaneTarget.innerHTML = renderVisualizationGallery({
      availableVisualizationTypes: this.availableVisualizationTypes(),
      visualizations: this.visualizations,
      readOnly: this.readOnlyValue,
      i18n: this.i18n
    });
  }

  private renderVisualizationPreviewOnly(): void {
    const host = this.visualizationPaneTarget.querySelector('[data-query-editor-preview-host]');
    const draft = this.currentVisualizationDraft();
    if (!(host instanceof HTMLElement) || !draft) return;

    host.innerHTML = renderVisualizationPreview({
      draft,
      result: this.result,
      themeLibrary: this.themeLibrary(),
      i18n: this.i18n
    });
  }

  private renderSettingsPane(): void {
    this.settingsPaneTarget.innerHTML = renderQuerySettingsPane({
      query: this.query,
      readOnly: this.readOnlyValue,
      i18n: this.i18n,
      chatSource: this.bootstrap.chat_source,
      availableGroups: this.availableQueryGroups(),
      groupInputValue: this.groupInputValue,
      groupMenuOpen: this.groupMenuOpen
    });
  }

  private renderFooter(): void {
    const isSavedQuery = this.query.saved;
    const changesCount = this.dirtyCount();

    this.runButtonTarget.textContent = this.translate('actions.run');
    this.runHintTarget.textContent = this.translate('actions.shortcut');
    this.runButtonTarget.disabled = !this.runEnabled();

    this.saveLabelTarget.textContent = isSavedQuery
      ? this.translate('actions.save_changes')
      : this.translate('actions.save_query');
    this.saveCountTarget.textContent = isSavedQuery && changesCount > 0 ? ` ${changesCount}` : '';
    this.saveButtonTarget.disabled = !this.saveEnabled();
  }

  private availableVisualizationTypes(): VisualizationType[] {
    return this.bootstrap.available_visualization_types;
  }

  private themeLibrary(): ThemeEntry[] {
    return this.bootstrap.theme_library;
  }

  private availableQueryGroups(): string[] {
    return sortGroupNames(this.bootstrap.available_query_groups || []);
  }

  private currentVisualizationDraft(): VisualizationDraft | null {
    if (!this.activeVisualizationType) return null;
    return this.visualizations[this.activeVisualizationType] || null;
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
    const values = [
      this.dataSourceSelectTarget?.value,
      this.dataSourceSelectTarget?.selectedOptions?.[0]?.value,
      String(this.query.data_source_id || '')
    ];

    for (const value of values) {
      const parsed = Number.parseInt(value || '', 10);
      if (Number.isFinite(parsed) && parsed > 0) return parsed;
    }

    return this.query.data_source_id;
  }

  private runEnabled(): boolean {
    return runEnabled(this.readOnlyValue, this.query.sql);
  }

  private shouldAutoRunOnLoad(): boolean {
    return Boolean(this.query.saved && this.query.sql?.trim() && !this.readOnlyValue);
  }

  private saveEnabled(): boolean {
    return saveEnabled({
      readOnly: this.readOnlyValue,
      query: this.query,
      baselineQuery: this.baselineQuery,
      visualizations: this.visualizations,
      baselineVisualizations: this.baselineVisualizations,
      result: this.result,
      runToken: this.runToken,
      lastSuccessfulFingerprint: this.lastSuccessfulFingerprint,
      currentDataSourceId: this.currentDataSourceId()
    });
  }

  private dirtyCount(): number {
    return dirtyCount(
      this.query,
      this.baselineQuery,
      this.visualizations,
      this.baselineVisualizations,
      this.currentDataSourceId()
    );
  }

  private currentFingerprint(): string | null {
    return currentFingerprint(this.currentDataSourceId(), this.query.sql);
  }

  private syncResultForCurrentSql(): void {
    if (this.currentFingerprint() && this.currentFingerprint() === this.lastSuccessfulFingerprint) {
      this.result = deepClone(this.lastSuccessfulResult);
      return;
    }

    this.result = null;
  }

  private shouldGenerateNameAfterRun(): boolean {
    return Boolean(
      !this.query.saved &&
      !this.generatedNameLocked &&
      !this.generatedNameAttempted &&
      this.result &&
      !this.result.error
    );
  }

  private requestGeneratedNameIfNeeded(): void {
    if (!this.generatedNamePending) return;

    const requestFingerprint = this.currentFingerprint();
    this.generatedNameAttempted = true;

    requestJson(this.generateNameUrlValue, {
      data_source_id: this.currentDataSourceId(),
      sql: this.query.sql,
      name: this.query.name
    }).then((payload) => {
      const generatedName = payload.data?.generated_name;
      const sameFingerprint = requestFingerprint && requestFingerprint === this.currentFingerprint();

      if (generatedName && sameFingerprint && !this.generatedNameLocked && !this.query.name?.trim()) {
        this.query.name = generatedName;
        this.generatedNameLocked = true;
      }

      this.generatedNamePending = false;
      this.renderPanelTitle();
      this.renderFooter();
    }).catch((_error: JsonRequestError) => {
      this.generatedNamePending = false;
      this.renderPanelTitle();
      this.renderFooter();
    });
  }

  private translate(path: string): string {
    return translate(this.i18n, path);
  }

  private persistTabParam(): void {
    const url = new URL(window.location.href);
    url.searchParams.set('tab', this.activeTab);
    window.history.replaceState({}, '', `${url.pathname}?${url.searchParams.toString()}`);
  }

  private parseJsonTarget<T>(target: HTMLScriptElement): T {
    return JSON.parse(target.textContent || '{}') as T;
  }

  private commitGroupInput(): void {
    const normalizedInput = normalizeGroupName(this.groupInputValue);
    if (!normalizedInput) return;

    const existingGroup = resolveExistingGroupName(this.availableQueryGroups(), normalizedInput);
    this.addGroupName(existingGroup || normalizedInput);
  }

  private addGroupName(value: string): void {
    const normalizedName = normalizeGroupName(value);
    if (!normalizedName || hasGroupName(this.query.group_names, normalizedName)) return;

    this.query.group_names = sortGroupNames([...this.query.group_names, normalizedName]);
    this.groupInputValue = '';
    this.groupMenuOpen = false;
    this.renderSettingsPane();
    this.renderFooter();
  }

  private shouldShowGroupMenu(): boolean {
    return this.availableQueryGroups().length > 0 || Boolean(normalizeGroupName(this.groupInputValue));
  }

  private focusGroupInputField(): void {
    const input = this.settingsPaneTarget.querySelector<HTMLInputElement>('[data-query-editor-group-input]');
    if (!input) return;

    input.focus({ preventScroll: true });
    const length = this.groupInputValue.length;
    input.setSelectionRange(length, length);
  }

  private showToast(type: 'success' | 'error' | 'information', title: string, body: string): void {
    showToast(type, title, body, this.translate('common.close'));
  }
}
