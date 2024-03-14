import { Controller } from '@hotwired/stimulus';

const MIN_SIZE = 600;

export default class extends Controller<HTMLDivElement> { 
  static targets = ['handle'];

  private isDragging: boolean = false;

  declare readonly handleTarget: HTMLFormElement;

  public connect(): void {
    this.handleTarget.addEventListener('mousedown', this.handleMouseDown);

    window.addEventListener('mouseup', this.handleMouseUp);
    window.addEventListener('mousemove', this.handleMouseMove);
  }

  public disconnect(): void {
    this.handleTarget.removeEventListener('mousedown', this.handleMouseDown, true);

    window.removeEventListener('mouseup', this.handleMouseUp, true);
    window.removeEventListener('mousemove', this.handleMouseMove, true);
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
      const value = Math.min(Math.max(event.clientX, MIN_SIZE), window.innerWidth - MIN_SIZE);

      document.body.style.gridTemplateColumns = `${value}px minmax(0, 1fr)`;
    }
  };
}
