import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['button', 'source'];

  declare readonly buttonTarget: HTMLButtonElement;
  declare readonly sourceTarget: HTMLElement;

  public copy(): void {
    const originalText = this.buttonTarget.innerText;

    this.buttonTarget.innerText = '[Copied!]';
    navigator.clipboard.writeText(this.sourceTarget.innerText);

    setTimeout(() => this.buttonTarget.innerText = originalText, 1000);
  }
}
