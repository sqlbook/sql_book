import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['button', 'dropdown'];

  toggle() {
    this.element.classList.toggle('open');
  }
}
