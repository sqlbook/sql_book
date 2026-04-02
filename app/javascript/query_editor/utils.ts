export function normalizeSql(value: string | null | undefined): string | null {
  const normalized = (value || '').trim().replace(/;\s*$/, '').replace(/\s+/g, ' ').trim();
  return normalized || null;
}

export function fingerprintFor(dataSourceId: number, sql: string | null | undefined): string | null {
  const normalizedSql = normalizeSql(sql);
  if (!dataSourceId || !normalizedSql) return null;

  return `${dataSourceId}:${normalizedSql}`;
}

export function deepClone<T>(value: T): T {
  return JSON.parse(JSON.stringify(value));
}

export function deepEqual(left: unknown, right: unknown): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

export function escapeHtml(value: string | null | undefined): string {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

export function escapeAttribute(value: string | null | undefined): string {
  return escapeHtml(value);
}

export function optionMarkup(value: string, label: string, selectedValue: string): string {
  return `<option value="${escapeAttribute(value)}" ${value === selectedValue ? 'selected' : ''}>${escapeHtml(label)}</option>`;
}

export function normalizeFieldValue(value: string): string | boolean {
  if (value === 'true') return true;
  if (value === 'false') return false;
  return value;
}

export function humanize(value: string | null | undefined): string {
  return String(value ?? '')
    .replaceAll('_', ' ')
    .trim()
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

export function interpolate(template: string | null | undefined, values: Record<string, string>): string {
  return Object.entries(values).reduce((memo, [key, value]) => {
    return memo.replaceAll(`%{${key}}`, value);
  }, String(template ?? ''));
}

export function translate(payload: Record<string, any>, path: string): string {
  return path.split('.').reduce<any>((memo, key) => memo?.[key], payload) || '';
}

export function dig(payload: Record<string, any>, path: string[]): unknown {
  return path.reduce<any>((memo, key) => memo?.[key], payload);
}

export function deepMerge(left: Record<string, any>, right: Record<string, any>): Record<string, any> {
  const result = deepClone(left);
  Object.entries(right || {}).forEach(([key, value]) => {
    if (
      value &&
      typeof value === 'object' &&
      !Array.isArray(value) &&
      result[key] &&
      typeof result[key] === 'object' &&
      !Array.isArray(result[key])
    ) {
      result[key] = deepMerge(result[key], value as Record<string, any>);
      return;
    }

    result[key] = value;
  });
  return result;
}
