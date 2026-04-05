import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLMenuElement> {
  static targets = ['button', 'dropdown'];

  private readonly handleDocumentClick = (event: MouseEvent): void => {
    const target = event.target;
    if (!(target instanceof Node)) return;
    if (this.element.contains(target)) return;

    this.close();
  };

  public connect(): void {
    document.addEventListener('click', this.handleDocumentClick);
  }

  public disconnect(): void {
    document.removeEventListener('click', this.handleDocumentClick);
  }

  public toggle(): void {
    if (this.element.classList.contains('open')) {
      this.close();
      return;
    }

    this.closeOtherMenus();
    this.element.classList.add('open');
  }

  public close(): void {
    this.element.classList.remove('open');
  }

  public changeWorkspace(event: Event): void {
    const target = event.target as HTMLSelectElement;
    const rootTemplate = target.dataset.workspaceRootTemplate || '/app/workspaces/__WORKSPACE_ID__';
    const destination = rootTemplate.replace('__WORKSPACE_ID__', target.value);

    window.Turbo.visit(destination, { action: 'replace' });
  }

  private closeOtherMenus(): void {
    const menus = document.querySelectorAll('menu[data-controller~="menu"].open');
    menus.forEach((menu) => {
      if (menu !== this.element) menu.classList.remove('open');
    });
  }
}
