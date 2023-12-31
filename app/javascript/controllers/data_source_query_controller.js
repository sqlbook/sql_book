import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['form', 'submit'];

  connect() {
    this.setButtonDisabled('');
  }

  change(event) {
    const value = event.target.value.toLowerCase();

    event.target.rows = value.split('\n').length;

    this.setButtonDisabled(value);
  }

  setButtonDisabled(value) {
    const maybeValidQuery = value.includes('select') && value.includes('from');
    
    if (this.formTarget.checkValidity() && maybeValidQuery) {
      this.submitTarget.removeAttribute('disabled');
    } else {
      this.submitTarget.setAttribute('disabled', 'true');
    }
  }
}
