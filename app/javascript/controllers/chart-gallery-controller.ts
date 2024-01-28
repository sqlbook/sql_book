import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['form'];
  
  declare readonly formTarget: HTMLFormElement;

  public submit() {
    this.formTarget.requestSubmit();
  }
}
