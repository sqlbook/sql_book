import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['toast'];

  declare readonly toastTargets: HTMLDivElement[];

  public connect(): void {
    this.toastTargets.forEach((toast) => {
      const autoDismissMs = Number(toast.dataset.autoDismissMs || 0);

      if (autoDismissMs > 0) {
        window.setTimeout(() => this.removeToast(toast), autoDismissMs);
      }
    });
  }

  public dismiss(event: Event): void {
    const target = event.target as HTMLElement;
    const toast = target.closest('.toast') as HTMLDivElement | null;

    if (!toast) return;

    this.removeToast(toast);
  }

  private removeToast(toast: HTMLDivElement): void {
    toast.remove();

    if (this.toastTargets.length === 0) {
      this.element.remove();
    }
  }
}
