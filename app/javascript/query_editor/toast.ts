import { escapeAttribute, escapeHtml } from './utils';

export function showToast(type: 'success' | 'error' | 'information', title: string, body: string, closeLabel: string): void {
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
      <button type="button" class="toast-close" aria-label="${escapeAttribute(closeLabel)}" data-action="click->toast-stack#dismiss">
        <i class="ri-close-line"></i>
      </button>
    </div>
    ${body ? `<p class="toast-body">${escapeHtml(body)}</p>` : ''}
  `;

  stack.appendChild(toast);
}
