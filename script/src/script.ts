import { Click, PageView, Session } from './listeners';
import { Event } from './types/events/event';

export class Script {
  private listeners = [
    Click,
    PageView,
    Session,
  ];

  public constructor() {
    this.listeners.forEach(listener => new listener());
  }

  private onEvent(event: Event) {
    
  }
}
