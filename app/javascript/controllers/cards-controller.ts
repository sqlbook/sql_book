import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  public show(event: MouseEvent): void {
    const target = event.target as HTMLElement;

    const isLink = target.closest('a');
    const card = target.closest('.card');

    if (!isLink && card) {
      // Assumes first link in the card is the 
      // primary, could cause problems
      const primaryLink = card.querySelector('a');
      window.Turbo.visit(primaryLink, { action: 'replace' });
    }
  }
}
