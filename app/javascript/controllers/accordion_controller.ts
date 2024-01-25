import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  public toggle(): void {
    this.element.classList.toggle('open');
  }
}
