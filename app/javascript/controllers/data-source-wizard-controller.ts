import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLFormElement> {
  static targets = ['connectionBox', 'databaseType'];

  declare readonly connectionBoxTarget: HTMLDivElement;
  declare readonly databaseTypeTarget: HTMLSelectElement;

  public connect(): void {
    this.toggleConnectionBox();
  }

  public toggleConnectionBox(): void {
    const showingPlaceholder = this.databaseTypeTarget.value === '';

    this.connectionBoxTarget.hidden = showingPlaceholder;
    this.databaseTypeTarget.closest('.select')?.classList.toggle('select--placeholder', showingPlaceholder);
  }
}
