export type QueryResultPayload = {
  error: boolean;
  error_message?: string | null;
  columns: string[];
  rows: Array<Array<string | number | boolean | null>>;
  row_count: number;
} | null;

export type ThemeEntry = {
  reference_key: string;
  name: string;
  default: boolean;
  read_only: boolean;
  system_theme: boolean;
  theme_json_dark: Record<string, unknown>;
  theme_json_light: Record<string, unknown>;
};

export type VisualizationType = {
  chart_type: string;
  icon: string;
  asset_path: string;
  label: string;
  description: string;
  renderer: string;
  enabled: boolean;
};

export type VisualizationDraft = {
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

export type VisualizationSavePayload = {
  chart_type: string;
  theme_reference: string;
  data_config: Record<string, unknown>;
  other_config: Record<string, unknown>;
  appearance_editor_dark: Record<string, string>;
  appearance_editor_light: Record<string, string>;
  appearance_raw_json_dark: string;
  appearance_raw_json_light: string;
};

export type QueryPayload = {
  id: number | null;
  saved: boolean;
  name: string | null;
  sql: string | null;
  data_source_id: number;
  canonical_path?: string | null;
};

export type QueryEditorTab = 'query_results' | 'visualization' | 'settings';

export type BootstrapPayload = {
  query: QueryPayload;
  result: QueryResultPayload;
  run_token?: string | null;
  visualizations: VisualizationDraft[];
  available_visualization_types: VisualizationType[];
  theme_library: ThemeEntry[];
  chat_source?: { path: string } | null;
  active_tab: QueryEditorTab;
};

export type TranslationPayload = Record<string, any>;
