import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['form', 'submit'];
  static values = { requireChange: { type: Boolean, default: false } };

  declare readonly formTarget: HTMLFormElement;
  declare readonly submitTarget: HTMLButtonElement;
  declare readonly requireChangeValue: boolean;

  private initialFormState = '';

  public connect(): void {
    this.initialFormState = this.formState();
    this.setButtonDisabled();
    this.formTarget.addEventListener('input', () => this.setButtonDisabled());
  }

  private setButtonDisabled(): void {
    const isValid = this.formTarget.checkValidity();
    const hasChanges = !this.requireChangeValue || this.formState() !== this.initialFormState;

    if (isValid && hasChanges) {
      this.submitTarget.removeAttribute('disabled');
    } else {
      this.submitTarget.setAttribute('disabled', 'true');
    }
  }

  private formState(): string {
    const fields = Array.from(this.formTarget.elements).filter((field) => {
      return field instanceof HTMLInputElement ||
        field instanceof HTMLSelectElement ||
        field instanceof HTMLTextAreaElement;
    });

    return fields.map((field) => {
      if (field instanceof HTMLInputElement && (field.type === 'checkbox' || field.type === 'radio')) {
        return `${field.name}:${field.checked}`;
      }

      return `${field.name}:${field.value}`;
    }).join('|');
  }
}
