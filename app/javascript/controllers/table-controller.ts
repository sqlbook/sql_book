import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['table'];

  declare readonly tableTarget: HTMLFormElement;
  private resizeObserver?: ResizeObserver;

  public connect(): void {
    document.addEventListener('click', this.onDocumentClick);
    window.addEventListener('resize', this.onWindowResize);
    this.setupResizeObserver();
    this.updateTooltipsAfterLayout();
    if ('fonts' in document) {
      document.fonts.ready.then(() => this.updateTooltipsAfterLayout());
    }
  }

  public disconnect(): void {
    document.removeEventListener('click', this.onDocumentClick);
    window.removeEventListener('resize', this.onWindowResize);
    this.resizeObserver?.disconnect();
  }

  public toggleOptions(event: MouseEvent): void {
    const target = event.target as HTMLElement;
    const row = target.closest('tr');

    this.closeAllContexts();

    if (row) {
      this.showRowContext(row);
    }
  }

  private onDocumentClick = (event: MouseEvent): void => {
    const target = event.target as HTMLElement;
    
    if (!target.closest('tr')) {
      this.closeAllContexts();
    }
  }

  private closeAllContexts = (): void => {
    this.element.querySelectorAll<HTMLTableRowElement>('table tr').forEach(row => {
      this.hideRowContext(row);
    });
  }

  private showRowContext(row: HTMLTableRowElement): void {
    row.classList.add('active');
    row.querySelector('.context')?.classList.add('show');
  }

  private hideRowContext(row: HTMLTableRowElement): void {
    row.classList.remove('active');
    row.querySelector('.context')?.classList.remove('show');
  }

  private onWindowResize = (): void => {
    this.updateTooltipsAfterLayout();
  }

  private setupResizeObserver(): void {
    if (!('ResizeObserver' in window)) return;

    this.resizeObserver = new ResizeObserver(() => this.updateTooltipsAfterLayout());
    this.resizeObserver.observe(this.element);
  }

  private updateTooltipsAfterLayout(): void {
    requestAnimationFrame(() => this.updateTruncationTooltips());
  }

  private updateTruncationTooltips(): void {
    this.element.querySelectorAll<HTMLElement>('.truncate-text[data-tooltip-text]').forEach(textNode => {
      const cell = textNode.closest<HTMLTableCellElement>('th, td');
      if (!cell) return;

      const text = textNode.dataset.tooltipText?.trim();
      if (!text) {
        cell.removeAttribute('data-tooltip');
        textNode.removeAttribute('title');
        return;
      }

      if (textNode.scrollWidth > textNode.clientWidth) {
        cell.setAttribute('data-tooltip', text);
        textNode.setAttribute('title', text);
      } else {
        cell.removeAttribute('data-tooltip');
        textNode.removeAttribute('title');
      }
    });
  }
}
