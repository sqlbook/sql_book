import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['form', 'submit'];

  declare readonly formTarget: HTMLFormElement;
  declare readonly submitTarget: HTMLButtonElement;

  connect() {
    this.setButtonDisabled();
    this.formTarget.addEventListener('input', () => this.setButtonDisabled());
  }

  setButtonDisabled() {
    if (this.formTarget.checkValidity()) {
      this.submitTarget.removeAttribute('disabled');
    } else {
      this.submitTarget.setAttribute('disabled', 'true');
    }
  }
}
