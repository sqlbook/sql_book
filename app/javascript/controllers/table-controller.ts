import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['table'];

  declare readonly tableTarget: HTMLFormElement;

  public connect(): void {
    document.addEventListener('click', this.onDocumentClick);
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
    document.querySelectorAll<HTMLTableRowElement>('table tr').forEach(row => {
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
}
