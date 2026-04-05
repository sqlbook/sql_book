import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['panel', 'toggleButton'];

  static values = {
    defaultOpen: Boolean,
    mobileBreakpoint: Number,
    openAria: String,
    closeAria: String
  };

  declare readonly panelTarget: HTMLElement;
  declare readonly toggleButtonTarget: HTMLButtonElement;

  declare readonly hasPanelTarget: boolean;
  declare readonly hasToggleButtonTarget: boolean;

  declare readonly defaultOpenValue: boolean;
  declare readonly mobileBreakpointValue: number;
  declare readonly openAriaValue: string;
  declare readonly closeAriaValue: string;

  private open = true;

  private readonly handleResize = (): void => {
    this.syncState();
  };

  public connect(): void {
    this.open = this.defaultOpenValue;
    this.syncState();

    window.addEventListener('resize', this.handleResize);
  }

  public disconnect(): void {
    window.removeEventListener('resize', this.handleResize);
  }

  public togglePanel(event: Event): void {
    event.preventDefault();
    this.setOpen(!this.open);
  }

  public openPanel(): void {
    this.setOpen(true);
  }

  public closePanel(event: Event): void {
    event.preventDefault();
    this.setOpen(false);
  }

  private setOpen(open: boolean): void {
    this.open = open;
    this.syncState();
  }

  private syncState(): void {
    this.element.classList.toggle('side-panel-layout--open', this.open);
    this.element.classList.toggle('side-panel-layout--closed', !this.open);

    if (this.hasPanelTarget) {
      this.panelTarget.setAttribute('aria-hidden', String(!this.open && this.mobileViewport()));
    }

    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.setAttribute('aria-expanded', String(this.open));
      this.toggleButtonTarget.setAttribute('aria-label', this.open ? this.closeAriaValue : this.openAriaValue);
    }
  }

  private mobileViewport(): boolean {
    return window.innerWidth <= this.mobileBreakpointValue;
  }
}
