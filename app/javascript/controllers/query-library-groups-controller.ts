import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLElement> {
  static targets = ['dialog', 'form', 'groupName'];

  declare readonly dialogTarget: HTMLDivElement;
  declare readonly formTarget: HTMLFormElement;
  declare readonly groupNameTarget: HTMLElement;

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
}
