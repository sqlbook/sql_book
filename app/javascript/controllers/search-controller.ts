import { Controller } from '@hotwired/stimulus';
import { debounce } from '../utils/debounce';

export default class extends Controller<HTMLDivElement> {
  static targets = ['form'];

  declare readonly formTarget: HTMLFormElement;

  initialize() {
    this.change = debounce(this.change, 500);
  }

  public change() {
    this.formTarget.requestSubmit();
  }
}
