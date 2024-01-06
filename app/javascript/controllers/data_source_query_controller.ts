import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['form', 'submit'];

  declare readonly formTarget: HTMLFormElement;
  declare readonly submitTarget: HTMLButtonElement;

  connect(): void {
    this.setButtonDisabled('');
  }

  change(event: Event): void {
    if (!event.target) return;

    const target = event.target as HTMLTextAreaElement;
    const value = target.value.toLowerCase();

    target.rows = value.split('\n').length;

    this.setButtonDisabled(value);
  }

  setButtonDisabled(value: string): void {
    const maybeValidQuery = value.includes('select') && value.includes('from');
    
    if (this.formTarget.checkValidity() && maybeValidQuery) {
      this.submitTarget.removeAttribute('disabled');
    } else {
      this.submitTarget.setAttribute('disabled', 'true');
    }
  }
}


const element = document.querySelector('select');

element?.addEventListener('change', event => event)