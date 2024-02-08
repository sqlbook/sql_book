import { Controller } from '@hotwired/stimulus';

let accordions: string[] = [];

export default class extends Controller<HTMLDivElement> {
  public connect(): void {
    if (accordions.includes(this.label)) {
      this.element.classList.add('open');
    }
  }

  public toggle(): void {
    if (this.element.classList.contains('open')) {
      this.element.classList.remove('open');
      accordions = accordions.filter(a => a === this.label);
    } else {
      this.element.classList.add('open');
      accordions.push(this.label);
    }
  }

  private get label(): string {
    return this.element.getAttribute('data-label')!;
  }
}
