import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['form', 'field', 'saveButton', 'discardButton'];

  declare readonly formTarget: HTMLFormElement;
  declare readonly fieldTargets: Array<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>;
  declare readonly saveButtonTarget: HTMLButtonElement;
  declare readonly discardButtonTarget: HTMLButtonElement;

  private initialState = new Map<string, string>();

  public connect(): void {
    this.captureInitialState();
    this.fieldTargets.forEach((field) => {
      field.addEventListener('input', this.onInput);
      field.addEventListener('change', this.onInput);
    });
    this.updateActionState();
  }

  public disconnect(): void {
    this.fieldTargets.forEach((field) => {
      field.removeEventListener('input', this.onInput);
      field.removeEventListener('change', this.onInput);
    });
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

  private onInput = (): void => {
    this.updateActionState();
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
}
