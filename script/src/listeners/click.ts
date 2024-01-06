import { ClickEvent } from '../types/events/click';

type Handler = (event: ClickEvent) => void;

export class Click {
  private fireEvent: Handler;

  public constructor(handler: Handler) {
    this.fireEvent = handler;

    document.addEventListener('click', this.onClick);
  }

  private onClick(event: MouseEvent) {
    console.log(event);
    // this.fireEvent({
      // coordinates_x: event.
    // });
  }
}
