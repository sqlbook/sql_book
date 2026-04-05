import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['form', 'field', 'saveButton', 'discardButton', 'filterForm', 'filterField', 'filterSearch', 'filterSearchClear'];

  declare readonly formTarget: HTMLFormElement;
  declare readonly fieldTargets: Array<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>;
  declare readonly saveButtonTarget: HTMLButtonElement;
  declare readonly discardButtonTarget: HTMLButtonElement;
  declare readonly hasFilterFormTarget: boolean;
  declare readonly filterFormTarget: HTMLFormElement;
  declare readonly filterFieldTargets: Array<HTMLInputElement | HTMLSelectElement>;
  declare readonly hasFilterSearchClearTarget: boolean;
  declare readonly hasFilterSearchTarget: boolean;
  declare readonly filterSearchClearTarget: HTMLButtonElement;
  declare readonly filterSearchTarget: HTMLInputElement;

  private initialState = new Map<string, string>();
  private filterDebounceTimer: number | null = null;
  private readonly searchMinChars = 3;

  public connect(): void {
    this.captureInitialState();
    this.fieldTargets.forEach((field) => {
      field.addEventListener('input', this.onInput);
      field.addEventListener('change', this.onInput);
    });
    this.filterFieldTargets.forEach((field) => {
      field.addEventListener('input', this.onFilterInput);
      field.addEventListener('change', this.onFilterChange);
    });
    this.toggleFilterSearchClear();
    this.updateActionState();
  }

  public disconnect(): void {
    this.fieldTargets.forEach((field) => {
      field.removeEventListener('input', this.onInput);
      field.removeEventListener('change', this.onInput);
    });
    this.filterFieldTargets.forEach((field) => {
      field.removeEventListener('input', this.onFilterInput);
      field.removeEventListener('change', this.onFilterChange);
    });
    if (this.filterDebounceTimer !== null) {
      window.clearTimeout(this.filterDebounceTimer);
      this.filterDebounceTimer = null;
    }
  }

  public discard(): void {
    this.fieldTargets.forEach((field) => {
      const initialValue = this.initialState.get(this.fieldKey(field));
      if (initialValue !== undefined) {
        field.value = initialValue;
      }
    });
    this.updateActionState();
  }

  public clearFilterSearch(): void {
    if (!this.hasFilterSearchTarget) return;
    if (this.filterSearchTarget.value === '') return;

    this.filterSearchTarget.value = '';
    this.toggleFilterSearchClear();
    this.filterSearchTarget.focus();
    this.submitFilterForm();
  }

  public toggleFilterSearchClear(): void {
    if (!this.hasFilterSearchClearTarget || !this.hasFilterSearchTarget) return;

    this.filterSearchClearTarget.hidden = this.filterSearchTarget.value.trim() === '';
  }

  private onInput = (): void => {
    this.updateActionState();
  }

  private onFilterInput = (event: Event): void => {
    if (!(event.target instanceof HTMLInputElement) || !['text', 'search'].includes(event.target.type)) {
      return;
    }

    this.toggleFilterSearchClear();

    const query = event.target.value.trim();
    if (query.length > 0 && query.length < this.searchMinChars) {
      return;
    }

    if (this.filterDebounceTimer !== null) {
      window.clearTimeout(this.filterDebounceTimer);
    }

    this.filterDebounceTimer = window.setTimeout(() => {
      this.submitFilterForm();
    }, 300);
  }

  private onFilterChange = (event: Event): void => {
    if (event.target instanceof HTMLSelectElement) {
      this.submitFilterForm();
    }
  }

  private captureInitialState(): void {
    this.initialState.clear();
    this.fieldTargets.forEach((field) => {
      this.initialState.set(this.fieldKey(field), this.initialFieldValue(field));
    });
  }

  private updateActionState(): void {
    const dirty = this.isDirty();
    this.saveButtonTarget.disabled = !dirty;
    this.discardButtonTarget.disabled = !dirty;
  }

  private isDirty(): boolean {
    return this.fieldTargets.some((field) => this.initialState.get(this.fieldKey(field)) !== field.value);
  }

  private fieldKey(field: HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement): string {
    return field.name;
  }

  private initialFieldValue(field: HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement): string {
    const value = field.dataset.initialValue;
    return value === undefined ? field.value : value;
  }

  private submitFilterForm(): void {
    if (!this.hasFilterFormTarget) {
      return;
    }

    if (this.filterDebounceTimer !== null) {
      window.clearTimeout(this.filterDebounceTimer);
      this.filterDebounceTimer = null;
    }

    this.filterFormTarget.requestSubmit();
  }
}
