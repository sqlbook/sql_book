import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['form'];
  
  declare readonly formTarget: HTMLFormElement;

  public connect(): void {
    // These are text inputs and should be on blur
    this.formTarget.querySelectorAll('input[type="text"]').forEach(element => {
      element.addEventListener('blur', this.submit);
    });

    // These can all submit the form immediately
    this.formTarget.querySelectorAll('select, input[type="radio"], input[type="checkbox"]').forEach(element => {
      element.addEventListener('change', this.submit);
    });
  }

  private submit = () => {
    this.formTarget.requestSubmit();
  }
}
