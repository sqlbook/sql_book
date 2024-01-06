import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLFormElement> {
  change(): void {
    this.element.requestSubmit();
  }
}
