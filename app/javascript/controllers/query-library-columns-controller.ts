import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLElement> {
  static targets = ['checkbox'];

  static values = {
    updateUrl: String,
    csrfToken: String
  };

  declare readonly checkboxTargets: HTMLInputElement[];

  declare readonly updateUrlValue: string;
  declare readonly csrfTokenValue: string;

  public toggleColumn(event: Event): void {
    const checkbox = event.currentTarget as HTMLInputElement;
    const columnKey = checkbox.dataset.columnKey;
    if (!columnKey) return;

    const previousChecked = !checkbox.checked;

    if (this.selectedColumns().length === 0) {
      checkbox.checked = true;
      return;
    }

    this.applyColumnVisibility(columnKey, checkbox.checked);

    this.persist().catch(() => {
      checkbox.checked = previousChecked;
      this.applyColumnVisibility(columnKey, previousChecked);
    });
  }

  private selectedColumns(): string[] {
    return this.checkboxTargets
      .filter((checkbox) => checkbox.checked)
      .map((checkbox) => checkbox.value);
  }

  private applyColumnVisibility(columnKey: string, visible: boolean): void {
    this.element.querySelectorAll<HTMLElement>(`[data-query-library-column-key="${columnKey}"]`).forEach((element) => {
      element.hidden = !visible;
    });
  }

  private async persist(): Promise<void> {
    const response = await window.fetch(this.updateUrlValue, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': this.csrfTokenValue
      },
      body: JSON.stringify({ visible_columns: this.selectedColumns() }),
      credentials: 'same-origin'
    });

    if (!response.ok) {
      throw new Error('Unable to update query library columns');
    }
  }
}
