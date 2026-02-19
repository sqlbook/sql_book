import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['table'];

  declare readonly tableTarget: HTMLFormElement;

  public connect(): void {
    document.addEventListener('click', this.onDocumentClick);
    window.addEventListener('resize', this.onWindowResize);
    this.updateTruncationTooltips();
  }

  public disconnect(): void {
    document.removeEventListener('click', this.onDocumentClick);
    window.removeEventListener('resize', this.onWindowResize);
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
    this.updateTruncationTooltips();
  }

  private updateTruncationTooltips(): void {
    this.element.querySelectorAll<HTMLTableCellElement>('th, td').forEach(cell => {
      if (cell.classList.contains('options') || cell.classList.contains('actions')) {
        cell.removeAttribute('data-tooltip');
        return;
      }

      if (cell.querySelector('a, button, input, select, textarea')) {
        cell.removeAttribute('data-tooltip');
        return;
      }

      const text = cell.textContent?.trim();
      if (!text) {
        cell.removeAttribute('data-tooltip');
        return;
      }

      if (cell.scrollWidth > cell.clientWidth) {
        cell.setAttribute('data-tooltip', text);
      } else {
        cell.removeAttribute('data-tooltip');
      }
    });
  }
}
