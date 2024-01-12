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
    const query = target.value;

    target.rows = query.split('\n').length;
    this.setButtonDisabled(query);
  }

  changeSource(event: Event): void {
    console.log('Change source');
  }

  submit(event: Event): void {
    if (!event.target) return;

    const target = event.target as HTMLTextAreaElement;
    
    if (this.isMaybeValidForm(target.value)) {
      this.formTarget.requestSubmit();
    }
  }

  setButtonDisabled(value: string): void {    
    if (this.isMaybeValidForm(value)) {
      this.submitTarget.removeAttribute('disabled');
    } else {
      this.submitTarget.setAttribute('disabled', 'true');
    }
  }

  isMaybeValidForm(value: string): boolean {
    if (!this.formTarget.checkValidity()) return false;

    const query = value.toLowerCase();

    return query.includes('select') && query.includes('from');
  }
}
