export function normalizeGroupName(value: string | null | undefined): string {
  return String(value ?? '')
    .replace(/\s+/g, ' ')
    .trim();
}

export function sortGroupNames(names: string[]): string[] {
  return dedupeGroupNames(names).sort((left, right) => {
    return left.localeCompare(right, undefined, { sensitivity: 'base' });
  });
}

export function dedupeGroupNames(names: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];

  names.forEach((name) => {
    const normalized = normalizeGroupName(name);
    if (!normalized) return;

    const key = normalized.toLocaleLowerCase();
    if (seen.has(key)) return;

    seen.add(key);
    result.push(normalized);
  });

  return result;
}

export function hasGroupName(names: string[], value: string): boolean {
  const normalized = normalizeGroupName(value).toLocaleLowerCase();
  if (!normalized) return false;

  return names.some((name) => normalizeGroupName(name).toLocaleLowerCase() === normalized);
}

export function resolveExistingGroupName(names: string[], value: string): string | null {
  const normalized = normalizeGroupName(value);
  if (!normalized) return null;

  return names.find((name) => {
    return normalizeGroupName(name).localeCompare(normalized, undefined, { sensitivity: 'base' }) === 0;
  }) || null;
}

export function groupNamesEqual(left: string[], right: string[]): boolean {
  const leftNames = sortGroupNames(left).map((name) => name.toLocaleLowerCase());
  const rightNames = sortGroupNames(right).map((name) => name.toLocaleLowerCase());

  if (leftNames.length !== rightNames.length) return false;
  return leftNames.every((name, index) => name === rightNames[index]);
}

export function filterGroupNames(available: string[], selected: string[], query: string): string[] {
  const search = normalizeGroupName(query).toLocaleLowerCase();

  return sortGroupNames(available).filter((name) => {
    if (hasGroupName(selected, name)) return false;
    if (!search) return true;

    return name.toLocaleLowerCase().includes(search);
  });
}
