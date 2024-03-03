import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['button', 'form'];

  declare readonly buttonTarget: HTMLButtonElement;
  declare readonly formTarget: HTMLFormElement;

  public show() {
    this.buttonTarget.classList.remove('show');
    this.formTarget.classList.add('show');
  }

  public hide() {
    this.buttonTarget.classList.add('show');
    this.formTarget.classList.remove('show');
  }
}
