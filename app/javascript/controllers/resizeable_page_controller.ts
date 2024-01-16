import { Controller } from '@hotwired/stimulus';

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

  private handleMouseUp = (event: MouseEvent) => {
    event.preventDefault();
    this.isDragging = false;
  };

  private handleMouseDown = (event: MouseEvent) => {
    event.preventDefault();
    this.isDragging = true;
  };

  private handleMouseMove = (event: MouseEvent) => {
    if (this.isDragging) {
      document.body.style.gridTemplateColumns = `${event.clientX}px minmax(0, 1fr)`;
    }
  };
}
