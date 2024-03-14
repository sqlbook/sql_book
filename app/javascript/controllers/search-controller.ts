import { Controller } from '@hotwired/stimulus';
import { debounce } from '../utils/debounce';

export default class extends Controller<HTMLDivElement> {
  static targets = ['form'];

  declare readonly formTarget: HTMLFormElement;

  public connect(): void {
    this.change = debounce(this.change, 500);
  }

  public change(): void {
    this.formTarget.requestSubmit();
  }
}
