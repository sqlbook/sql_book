import { Controller } from '@hotwired/stimulus';

const MIN_SIZE = 600;

// Keep the last value stored so it can be
// reset after tab changes
let columnWidth: number | undefined = undefined;

export default class extends Controller<HTMLDivElement> { 
  static targets = ['handle'];

  private isDragging: boolean = false;
  private layoutContainer: HTMLElement | null = null;

  declare readonly handleTarget: HTMLFormElement;

  public connect(): void {
    this.layoutContainer = this.element.closest('.app-content-layout.split');
    this.handleTarget.addEventListener('mousedown', this.handleMouseDown);

    window.addEventListener('mouseup', this.handleMouseUp);
    window.addEventListener('mousemove', this.handleMouseMove);
    window.addEventListener('resize', this.handleWindowResize);

    if (columnWidth) {
      this.setColumnWidth(columnWidth);
    }
  }

  public disconnect(): void {
    this.handleTarget.removeEventListener('mousedown', this.handleMouseDown);

    window.removeEventListener('mouseup', this.handleMouseUp);
    window.removeEventListener('mousemove', this.handleMouseMove);
    window.removeEventListener('resize', this.handleWindowResize);
  }

  private handleMouseUp = (event: MouseEvent): void => {
    event.preventDefault();
    this.isDragging = false;
  };

  private handleMouseDown = (event: MouseEvent): void => {
    event.preventDefault();
    this.isDragging = true;
  };

  private handleMouseMove = (event: MouseEvent): void => {
    if (this.isDragging) {
      const splitBounds = this.layoutContainer?.getBoundingClientRect();
      if (!splitBounds) return;
      this.setColumnWidth(event.clientX - splitBounds.left);
    }
  };

  private handleWindowResize = (): void => {
    if (columnWidth) {
      this.setColumnWidth(columnWidth);
    }
  };

  private setColumnWidth(width: number): void {
    if (!this.layoutContainer) return;
    const styles = window.getComputedStyle(this.layoutContainer);
    const gap = Number.parseFloat(styles.columnGap) || 0;
    const maxWidth = Math.max(MIN_SIZE, this.layoutContainer.clientWidth - MIN_SIZE - gap);
    const safeWidth = Math.min(Math.max(width, MIN_SIZE), maxWidth);

    columnWidth = safeWidth;
    this.layoutContainer.style.gridTemplateColumns = `${safeWidth}px minmax(0, 1fr)`;
  }
}
