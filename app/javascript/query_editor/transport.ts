export type PendingToast = {
  type: 'success' | 'error' | 'information';
  title: string;
  body: string;
};

export class JsonRequestError extends Error {
  code?: string;

  constructor(message: string, code?: string) {
    super(message);
    this.name = 'JsonRequestError';
    this.code = code;
  }
}

export function requestJson(path: string, payload: Record<string, unknown>): Promise<any> {
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
    if (!response.ok) throw new JsonRequestError(data.message || '', data.code || data.error_code);
    return data;
  });
}

export function turboVisit(path: string): void {
  const turbo = (window as Window & { Turbo?: { visit: (location: string, options?: { action?: string }) => void } }).Turbo;
  if (turbo) {
    turbo.visit(path, { action: 'replace' });
    return;
  }

  window.location.assign(path);
}

export function persistPendingToast(storageKey: string, toast: PendingToast): void {
  window.sessionStorage.setItem(storageKey, JSON.stringify(toast));
}

export function restorePendingToast(storageKey: string): PendingToast | null {
  const value = window.sessionStorage.getItem(storageKey);
  if (!value) return null;

  window.sessionStorage.removeItem(storageKey);

  try {
    return JSON.parse(value) as PendingToast;
  } catch (_error) {
    return null;
  }
}
