import type {
  QueryResultPayload,
  ThemeEntry,
  TranslationPayload,
  VisualizationDraft,
  VisualizationType
} from './types';
import {
  deepClone,
  deepMerge,
  dig,
  escapeAttribute,
  escapeHtml,
  humanize,
  optionMarkup
} from './utils';

type VisualizationGalleryParams = {
  availableVisualizationTypes: VisualizationType[];
  visualizations: Record<string, VisualizationDraft>;
  readOnly: boolean;
  i18n: TranslationPayload;
};

type VisualizationEditorParams = {
  draft: VisualizationDraft;
  columns: string[];
  readOnly: boolean;
  themeLibrary: ThemeEntry[];
  i18n: TranslationPayload;
};

type VisualizationPreviewParams = {
  draft: VisualizationDraft;
  result: QueryResultPayload;
  themeLibrary: ThemeEntry[];
  i18n: TranslationPayload;
};

export function defaultThemeReference(themeLibrary: ThemeEntry[]): string {
  return themeLibrary.find((theme) => theme.default)?.reference_key
    || themeLibrary[0]?.reference_key
    || 'system.default_theming';
}

export function buildDefaultVisualizationDraft({
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

export function resolvedDataConfig(draft: VisualizationDraft, columns: string[]): Record<string, any> {
  return { ...visualizationDefaultsData(draft.chart_type, columns), ...draft.data_config };
}

export function resolvedOtherConfig(draft: VisualizationDraft, columns: string[]): Record<string, any> {
  return { ...visualizationDefaultsOther(draft.chart_type, columns), ...draft.other_config };
}

export function resolveTheme(
  themeLibrary: ThemeEntry[],
  draft: VisualizationDraft,
  mode: 'dark' | 'light'
): Record<string, unknown> {
  const theme = themeLibrary.find((entry) => entry.reference_key === draft.theme_reference);
  const baseTheme = deepClone(mode === 'dark' ? theme?.theme_json_dark || {} : theme?.theme_json_light || {});
  const overrides = resolveAppearanceConfig(draft, mode);
  return deepMerge(baseTheme, overrides);
}

export function renderVisualizationGallery({
  availableVisualizationTypes,
  visualizations,
  readOnly,
  i18n
}: VisualizationGalleryParams): string {
  const galleryTranslations = i18n.visualizations;
  const cards = availableVisualizationTypes.map((visualizationType) => {
    const configured = Boolean(visualizations[visualizationType.chart_type]);
    return `
      <button
        type="button"
        class="visualization-gallery__card"
        data-chart-type="${escapeAttribute(visualizationType.chart_type)}"
        data-action="query-editor#selectVisualization">
        <i class="${escapeAttribute(visualizationType.icon)}" aria-hidden="true"></i>
        <span class="visualization-gallery__label">${escapeHtml(visualizationType.label)}</span>
        <span class="visualization-gallery__description">${escapeHtml(visualizationType.description)}</span>
        ${configured ? `<span class="visualization-gallery__badge">${escapeHtml(galleryTranslations.configured_badge)}</span>` : ''}
      </button>
    `;
  }).join('');

  if (readOnly) {
    return `
      <div class="visualization-gallery">
        <div class="visualization-gallery__header">
          <h4 class="cream-250">${escapeHtml(galleryTranslations.gallery_title)}</h4>
          <p class="gray-300">${escapeHtml(galleryTranslations.gallery_description)}</p>
        </div>
        <p class="gray-300">${escapeHtml(galleryTranslations.gallery_read_only)}</p>
      </div>
    `;
  }

  return `
    <div class="visualization-gallery">
      <div class="visualization-gallery__header">
        <h4 class="cream-250">${escapeHtml(galleryTranslations.gallery_title)}</h4>
        <p class="gray-300">${escapeHtml(galleryTranslations.gallery_description)}</p>
      </div>
      <div class="visualization-gallery__grid">
        ${cards}
      </div>
    </div>
  `;
}

export function renderVisualizationEditor({
  draft,
  columns,
  readOnly,
  themeLibrary,
  i18n
}: VisualizationEditorParams): string {
  const dataConfig = resolvedDataConfig(draft, columns);
  const otherConfig = resolvedOtherConfig(draft, columns);
  const themeOptions = themeLibrary.map((theme) => {
    return optionMarkup(
      theme.reference_key,
      theme.name + (theme.default ? ` · ${i18n.common.default_badge}` : ''),
      draft.theme_reference
    );
  }).join('');

  return `
    <div class="visualization-editor">
      <section class="visualization-editor__section">
        <div class="visualization-editor__section-heading">
          <button type="button" class="link secondary" data-action="query-editor#backToVisualizationGallery">
            ${escapeHtml(i18n.actions.back_to_gallery)}
          </button>
          ${readOnly ? '' : `
            <button type="button" class="link secondary" data-action="query-editor#removeVisualization">
              ${escapeHtml(i18n.actions.remove_visualization)}
            </button>
          `}
        </div>
        <div class="visualization-editor__section-heading">
          <h4 class="cream-250">${escapeHtml(i18n.visualizations.sections.preview)}</h4>
        </div>
        <div data-query-editor-preview-host></div>
      </section>

      <section class="visualization-editor__section" ${readOnly ? 'aria-disabled="true"' : ''}>
        <h4 class="cream-250">${escapeHtml(i18n.visualizations.sections.data)}</h4>
        ${chartDataFieldsMarkup({
          chartType: draft.chart_type,
          columns,
          dataConfig,
          disabled: readOnly,
          translations: i18n.visualizations.form
        })}
      </section>

      <section class="visualization-editor__section">
        <h4 class="cream-250">${escapeHtml(i18n.visualizations.sections.appearance)}</h4>
        <div>
          <label class="label block">${escapeHtml(i18n.visualizations.form.theme)}</label>
          <div class="select">
            <select data-scope="root" data-key="theme_reference" data-action="change->query-editor#changeVisualizationField" ${readOnly ? 'disabled' : ''}>
              ${themeOptions}
            </select>
            <i class="ri-arrow-drop-down-line"></i>
          </div>
        </div>
        <div class="split">
          ${textFieldMarkup(i18n.visualizations.form.title, 'other_config', 'title', otherConfig.title, readOnly)}
          ${textFieldMarkup(i18n.visualizations.form.subtitle, 'other_config', 'subtitle', otherConfig.subtitle, readOnly)}
        </div>
        ${cartesianMarkup({
          chartType: draft.chart_type,
          xAxisLabel: otherConfig.x_axis_label,
          yAxisLabel: otherConfig.y_axis_label,
          disabled: readOnly,
          translations: i18n.visualizations.form
        })}
        ${draft.chart_type === 'donut'
          ? singleTextFieldMarkup(i18n.visualizations.form.donut_inner_radius, 'other_config', 'donut_inner_radius', otherConfig.donut_inner_radius, readOnly, '58%')
          : ''}
        ${draft.chart_type === 'total'
          ? singleTextFieldMarkup(i18n.visualizations.form.total_label, 'other_config', 'total_label', otherConfig.total_label, readOnly)
          : ''}
        <div class="split">
          ${booleanSelectMarkup(i18n.visualizations.form.legend_enabled, 'other_config', 'legend_enabled', otherConfig.legend_enabled, readOnly, i18n.common)}
          ${booleanSelectMarkup(i18n.visualizations.form.tooltip_enabled, 'other_config', 'tooltip_enabled', otherConfig.tooltip_enabled, readOnly, i18n.common)}
        </div>
        <div class="visualization-editor__mode-grid">
          ${modeEditorMarkup('dark', draft.appearance_editor_dark, draft.appearance_raw_json_dark, readOnly, i18n.visualizations.form)}
          ${modeEditorMarkup('light', draft.appearance_editor_light, draft.appearance_raw_json_light, readOnly, i18n.visualizations.form)}
        </div>
      </section>

      <section class="visualization-editor__section">
        <h4 class="cream-250">${escapeHtml(i18n.visualizations.sections.sharing)}</h4>
        <div class="message">
          <i class="ri-information-line ri-lg red-500"></i>
          <div class="body">
            <p class="title cream-250">${escapeHtml(i18n.visualizations.sharing.title)}</p>
            <p>${escapeHtml(i18n.visualizations.sharing.body)}</p>
          </div>
        </div>
      </section>

      <section class="visualization-editor__section">
        <h4 class="cream-250">${escapeHtml(i18n.visualizations.sections.other)}</h4>
        <p class="gray-300">${escapeHtml(i18n.visualizations.other.description)}</p>
      </section>
    </div>
  `;
}

export function renderVisualizationPreview({
  draft,
  result,
  themeLibrary,
  i18n
}: VisualizationPreviewParams): string {
  if (!result) {
    return `<p class="gray-300">${escapeHtml(i18n.results.empty)}</p>`;
  }

  if (result.error) {
    return `<p class="red-500">${escapeHtml(result.error_message || '')}</p>`;
  }

  const columns = result.columns || [];
  const dataConfig = resolvedDataConfig(draft, columns);
  const otherConfig = resolvedOtherConfig(draft, columns);

  if (draft.chart_type === 'table') {
    const pageSize = Number(dataConfig.table_page_size || 10);
    return queryResultsTableMarkup(result, pageSize);
  }

  if (draft.chart_type === 'total') {
    const totalValue = totalVisualizationValue(result, String(dataConfig.value_key || ''));
    return `
      <div class="visualization-preview-total">
        <div class="visualization-preview-total__value">${escapeHtml(totalValue)}</div>
        ${otherConfig.total_label ? `<div class="visualization-preview-total__label">${escapeHtml(String(otherConfig.total_label))}</div>` : ''}
      </div>
    `;
  }

  const darkTheme = resolveTheme(themeLibrary, draft, 'dark');
  const lightTheme = resolveTheme(themeLibrary, draft, 'light');
  const darkOption = buildOption({
    chartType: draft.chart_type,
    result,
    dataConfig,
    otherConfig,
    theme: darkTheme
  });
  const lightOption = buildOption({
    chartType: draft.chart_type,
    result,
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

export function queryResultsTableMarkup(result: NonNullable<QueryResultPayload>, pageSize: number): string {
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

function themeEditorAttributes(themeJson: Record<string, unknown>): Record<string, string> {
  const payload = themeJson || {};

  return {
    colors_csv: Array((payload.color as string[]) || []).join(', '),
    background_color: String(payload.backgroundColor || ''),
    text_color: String(dig(payload, ['textStyle', 'color']) || ''),
    title_color: String(dig(payload, ['title', 'textStyle', 'color']) || ''),
    subtitle_color: String(dig(payload, ['title', 'subtextStyle', 'color']) || ''),
    legend_text_color: String(dig(payload, ['legend', 'textStyle', 'color']) || ''),
    axis_line_color: String(
      dig(payload, ['categoryAxis', 'axisLine', 'lineStyle', 'color']) ||
        dig(payload, ['valueAxis', 'axisLine', 'lineStyle', 'color']) ||
        ''
    ),
    axis_label_color: String(
      dig(payload, ['categoryAxis', 'axisLabel', 'color']) ||
        dig(payload, ['valueAxis', 'axisLabel', 'color']) ||
        ''
    ),
    split_line_color: String(
      dig(payload, ['categoryAxis', 'splitLine', 'lineStyle', 'color']) ||
        dig(payload, ['valueAxis', 'splitLine', 'lineStyle', 'color']) ||
        ''
    ),
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

function modeEditorMarkup(
  mode: 'dark' | 'light',
  editorValues: Record<string, string>,
  rawJson: string,
  readOnly: boolean,
  translations: Record<string, string>
): string {
  const labelKey = mode === 'dark' ? 'dark_mode' : 'light_mode';

  return `
    <div class="visualization-editor__mode-card">
      <h5 class="cream-250">${escapeHtml(translations[labelKey])}</h5>
      <div class="split">
        ${textFieldMarkup(translations.palette, 'appearance_editor', 'colors_csv', editorValues.colors_csv, readOnly, '#F5807B, #5CA1F2', mode)}
        ${textFieldMarkup(translations.background_color, 'appearance_editor', 'background_color', editorValues.background_color, readOnly, '#1C1C1C', mode)}
      </div>
      <div class="split">
        ${textFieldMarkup(translations.text_color, 'appearance_editor', 'text_color', editorValues.text_color, readOnly, '#ECEAE6', mode)}
        ${textFieldMarkup(translations.legend_text_color, 'appearance_editor', 'legend_text_color', editorValues.legend_text_color, readOnly, '', mode)}
      </div>
      <div class="split">
        ${textFieldMarkup(translations.title_color, 'appearance_editor', 'title_color', editorValues.title_color, readOnly, '', mode)}
        ${textFieldMarkup(translations.subtitle_color, 'appearance_editor', 'subtitle_color', editorValues.subtitle_color, readOnly, '', mode)}
      </div>
      <div class="split">
        ${textFieldMarkup(translations.axis_line_color, 'appearance_editor', 'axis_line_color', editorValues.axis_line_color, readOnly, '#505050', mode)}
        ${textFieldMarkup(translations.axis_label_color, 'appearance_editor', 'axis_label_color', editorValues.axis_label_color, readOnly, '', mode)}
      </div>
      <div class="split">
        ${textFieldMarkup(translations.split_line_color, 'appearance_editor', 'split_line_color', editorValues.split_line_color, readOnly, '#333333', mode)}
        ${textFieldMarkup(translations.tooltip_background_color, 'appearance_editor', 'tooltip_background_color', editorValues.tooltip_background_color, readOnly, '', mode)}
      </div>
      ${singleTextFieldMarkup(translations.tooltip_text_color, 'appearance_editor', 'tooltip_text_color', editorValues.tooltip_text_color, readOnly, '', mode)}
      <label class="label block">${escapeHtml(translations.raw_json)}</label>
      <textarea class="input block fluid visualization-editor__json"
                rows="10"
                data-scope="appearance_raw_json"
                data-mode="${mode}"
                data-key="raw_json"
                data-action="input->query-editor#changeVisualizationField"
                ${readOnly ? 'readonly' : ''}>${escapeHtml(rawJson || '')}</textarea>
    </div>
  `;
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
  translations
}: {
  chartType: string;
  columns: string[];
  dataConfig: Record<string, any>;
  disabled: boolean;
  translations: Record<string, string>;
}): string {
  const dimensionSelect = `
    <div>
      <label class="label block">${escapeHtml(translations.dimension_key)}</label>
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
      <label class="label block">${escapeHtml(translations.value_key)}</label>
      <div class="select">
        <select data-scope="data_config" data-key="value_key" data-action="change->query-editor#changeVisualizationField" ${disabled ? 'disabled' : ''}>
          ${columns.map((column) => optionMarkup(column, column, String(dataConfig.value_key || ''))).join('')}
        </select>
        <i class="ri-arrow-drop-down-line"></i>
      </div>
    </div>
  `;

  if (['line', 'area', 'column', 'bar', 'pie', 'donut'].includes(chartType)) {
    return `<div class="split">${dimensionSelect}${valueSelect}</div>`;
  }

  if (chartType === 'total') {
    return `<div class="split">${valueSelect}</div>`;
  }

  if (chartType === 'table') {
    return `
      <div>
        <label class="label block">${escapeHtml(translations.table_page_size)}</label>
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
  translations
}: {
  chartType: string;
  xAxisLabel: unknown;
  yAxisLabel: unknown;
  disabled: boolean;
  translations: Record<string, string>;
}): string {
  if (!['line', 'area', 'column', 'bar'].includes(chartType)) return '';

  return `
    <div class="split">
      ${textFieldMarkup(translations.x_axis_label, 'other_config', 'x_axis_label', xAxisLabel, disabled)}
      ${textFieldMarkup(translations.y_axis_label, 'other_config', 'y_axis_label', yAxisLabel, disabled)}
    </div>
  `;
}

function totalVisualizationValue(result: NonNullable<QueryResultPayload>, columnName: string): string {
  const index = result.columns.indexOf(columnName);
  if (index < 0) return '0';

  const value = result.rows[0]?.[index];
  return value === null || value === undefined ? '0' : String(value);
}
