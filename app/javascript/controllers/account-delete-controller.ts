import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['dialog', 'openButton', 'submit', 'actionSelect'];

  declare readonly dialogTarget: HTMLDivElement;
  declare readonly openButtonTarget: HTMLButtonElement;
  declare readonly submitTarget: HTMLElement;
  declare readonly actionSelectTargets: HTMLSelectElement[];

  public connect(): void {
    this.updateConfirmState();
  }

  public show(): void {
    this.openButtonTarget.classList.remove('show');
    this.dialogTarget.classList.add('show');
    this.updateConfirmState();
    requestAnimationFrame(() => window.dispatchEvent(new Event('resize')));
  }

  public hide(): void {
    this.openButtonTarget.classList.add('show');
    this.dialogTarget.classList.remove('show');
  }

  public updateConfirmState(): void {
    this.actionSelectTargets.forEach((select) => {
      const selectWrapper = select.closest('.account-delete-select');
      if (!(selectWrapper instanceof HTMLDivElement)) return;

      selectWrapper.classList.toggle('placeholder-selected', select.value === '');
      selectWrapper.classList.toggle(
        'danger-selected',
        select.value === 'delete'
      );

      const selectedOption = select.selectedOptions.item(0);
      if (selectedOption && selectedOption.value !== '') {
        select.setAttribute('title', selectedOption.text);
      } else {
        select.removeAttribute('title');
      }
    });

    const unresolvedSelect = this.actionSelectTargets.some((select) => select.value === '');
    this.submitTarget.toggleAttribute('disabled', unresolvedSelect);
  }
}
