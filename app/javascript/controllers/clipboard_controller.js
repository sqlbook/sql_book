import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['button', 'source'];

  copy() {
    const originalText = this.buttonTarget.innerText;

    this.buttonTarget.innerText = '[Copied!]';
    navigator.clipboard.writeText(this.sourceTarget.innerText);

    setTimeout(() => this.buttonTarget.innerText = originalText, 1000);
  }
}
