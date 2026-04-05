import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLElement> {
  static targets = ['dialog', 'form', 'groupName', 'toggleIcon'];

  declare readonly dialogTarget: HTMLDivElement;
  declare readonly formTarget: HTMLFormElement;
  declare readonly groupNameTarget: HTMLElement;

  public connect(): void {
    this.syncAllDrawerToggles();
  }

  public showDeleteDialog(event: Event): void {
    event.preventDefault();
    event.stopPropagation();

    const button = event.currentTarget as HTMLButtonElement;
    const deletePath = button.dataset.deletePath;
    const groupName = button.dataset.groupName;
    if (!deletePath || !groupName) return;

    this.formTarget.action = deletePath;
    this.groupNameTarget.textContent = groupName;
    this.dialogTarget.classList.add('show');
  }

  public hideDeleteDialog(event?: Event): void {
    event?.preventDefault();
    this.dialogTarget.classList.remove('show');
    this.formTarget.action = '';
    this.groupNameTarget.textContent = '';
  }

  public hideDeleteDialogIfBackdrop(event: MouseEvent): void {
    if (event.target !== this.dialogTarget) return;

    this.hideDeleteDialog();
  }

  public syncDrawerToggle(event: Event): void {
    const drawer = event.currentTarget;
    if (!(drawer instanceof HTMLDetailsElement)) return;

    this.syncDrawerIcon(drawer);
  }

  private syncAllDrawerToggles(): void {
    this.element.querySelectorAll<HTMLDetailsElement>('.query-group-drawer').forEach((drawer) => {
      this.syncDrawerIcon(drawer);
    });
  }

  private syncDrawerIcon(drawer: HTMLDetailsElement): void {
    const icon = drawer.querySelector<HTMLElement>('.query-group-drawer__toggle-icon');
    if (!icon) return;

    icon.classList.toggle('ri-add-line', !drawer.open);
    icon.classList.toggle('ri-subtract-line', drawer.open);
  }
}
