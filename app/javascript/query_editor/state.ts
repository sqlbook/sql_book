import type {
  QueryPayload,
  QueryResultPayload,
  VisualizationDraft,
  VisualizationSavePayload,
  VisualizationType
} from './types';
import { groupNamesEqual, sortGroupNames } from './groups';
import { deepClone, deepEqual, fingerprintFor, normalizeSql } from './utils';

type SaveEnabledParams = {
  readOnly: boolean;
  query: QueryPayload;
  baselineQuery: QueryPayload;
  visualizations: Record<string, VisualizationDraft>;
  baselineVisualizations: Record<string, VisualizationDraft>;
  result: QueryResultPayload;
  runToken: string | null;
  lastSuccessfulFingerprint: string | null;
  currentDataSourceId: number;
};

export function indexVisualizations(visualizations: VisualizationDraft[]): Record<string, VisualizationDraft> {
  return visualizations.reduce<Record<string, VisualizationDraft>>((memo, visualization) => {
    memo[visualization.chart_type] = visualization;
    return memo;
  }, {});
}

export function snapshotQuery(query: QueryPayload, dataSourceId: number): QueryPayload {
  return {
    id: query.id,
    saved: query.saved,
    name: query.name,
    sql: query.sql,
    data_source_id: dataSourceId,
    group_names: sortGroupNames(query.group_names || []),
    canonical_path: query.canonical_path
  };
}

export function snapshotVisualizations(
  visualizations: Record<string, VisualizationDraft>
): Record<string, VisualizationDraft> {
  return deepClone(visualizations);
}

export function querySurfaceDirty(query: QueryPayload, baselineQuery: QueryPayload, dataSourceId: number): boolean {
  return dataSourceId !== baselineQuery.data_source_id || normalizeSql(query.sql) !== normalizeSql(baselineQuery.sql);
}

export function settingsDirty(query: QueryPayload, baselineQuery: QueryPayload): boolean {
  return (query.name || '').trim() !== (baselineQuery.name || '').trim() ||
    !groupNamesEqual(query.group_names || [], baselineQuery.group_names || []);
}

export function dirtyVisualizationTypes(
  visualizations: Record<string, VisualizationDraft>,
  baselineVisualizations: Record<string, VisualizationDraft>
): string[] {
  const currentTypes = Object.keys(visualizations);
  const baselineTypes = Object.keys(baselineVisualizations);
  const types = Array.from(new Set([...currentTypes, ...baselineTypes]));

  return types.filter((chartType) => !deepEqual(visualizations[chartType] || null, baselineVisualizations[chartType] || null));
}

export function dirtyCount(
  query: QueryPayload,
  baselineQuery: QueryPayload,
  visualizations: Record<string, VisualizationDraft>,
  baselineVisualizations: Record<string, VisualizationDraft>,
  dataSourceId: number
): number {
  if (!query.saved) return 0;

  let count = 0;
  if (querySurfaceDirty(query, baselineQuery, dataSourceId)) count += 1;
  if (settingsDirty(query, baselineQuery)) count += 1;
  count += dirtyVisualizationTypes(visualizations, baselineVisualizations).length;
  return count;
}

export function runEnabled(readOnly: boolean, sql: string | null | undefined): boolean {
  return !readOnly && Boolean(normalizeSql(sql));
}

export function currentFingerprint(dataSourceId: number, sql: string | null | undefined): string | null {
  return fingerprintFor(dataSourceId, sql);
}

export function saveEnabled({
  readOnly,
  query,
  baselineQuery,
  visualizations,
  baselineVisualizations,
  result,
  runToken,
  lastSuccessfulFingerprint,
  currentDataSourceId
}: SaveEnabledParams): boolean {
  if (readOnly) return false;
  if (!normalizeSql(query.sql)) return false;

  const fingerprint = currentFingerprint(currentDataSourceId, query.sql);
  const currentRunIsFresh = Boolean(runToken && fingerprint && fingerprint === lastSuccessfulFingerprint && result && !result.error);

  if (!query.saved) return currentRunIsFresh;

  if (dirtyCount(query, baselineQuery, visualizations, baselineVisualizations, currentDataSourceId) === 0) return false;
  if (querySurfaceDirty(query, baselineQuery, currentDataSourceId)) return currentRunIsFresh;

  return true;
}

export function queryTitle(query: QueryPayload, untitledTitle: string): string {
  return query.name?.trim() || untitledTitle;
}

export function visualizationPayloadsForSave(
  availableVisualizationTypes: VisualizationType[],
  visualizations: Record<string, VisualizationDraft>
): VisualizationSavePayload[] {
  return availableVisualizationTypes
    .map((type) => visualizations[type.chart_type])
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
