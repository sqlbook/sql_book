import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  private resizeObserver?: ResizeObserver;

  public connect(): void {
    window.addEventListener('resize', this.onWindowResize);
    this.setupResizeObserver();
    this.updateTooltipsAfterLayout();
    if ('fonts' in document) {
      document.fonts.ready.then(() => this.updateTooltipsAfterLayout());
    }
  }

  public disconnect(): void {
    window.removeEventListener('resize', this.onWindowResize);
    this.resizeObserver?.disconnect();
  }

  private onWindowResize = (): void => {
    this.updateTooltipsAfterLayout();
  };

  private setupResizeObserver(): void {
    if (!('ResizeObserver' in window)) return;

    this.resizeObserver = new ResizeObserver(() => this.updateTooltipsAfterLayout());
    this.resizeObserver.observe(this.element);
  }

  private updateTooltipsAfterLayout(): void {
    requestAnimationFrame(() => this.updateTruncationTooltips());
  }

  private updateTruncationTooltips(): void {
    this.element.querySelectorAll<HTMLElement>('.breadcrumbs-item.middle .truncate-text[data-tooltip-text]').forEach(textNode => {
      const item = textNode.closest<HTMLElement>('.breadcrumbs-item');
      if (!item) return;

      const text = textNode.dataset.tooltipText?.trim();
      if (!text) {
        item.removeAttribute('data-tooltip');
        textNode.removeAttribute('title');
        return;
      }

      if (textNode.scrollWidth > textNode.clientWidth) {
        item.setAttribute('data-tooltip', text);
        textNode.setAttribute('title', text);
      } else {
        item.removeAttribute('data-tooltip');
        textNode.removeAttribute('title');
      }
    });
  }
}
