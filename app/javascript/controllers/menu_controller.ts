import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLMenuElement> {
  static targets = ['button', 'dropdown'];

  toggle(): void {
    this.element.classList.toggle('open');
  }
}