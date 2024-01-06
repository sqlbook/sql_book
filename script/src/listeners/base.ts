import { EventType } from '../types/events/event';
import { Event } from '../types/events/event';
import { Visitor } from '../utils/visitor';

type Handler = (type: EventType, event: Event) => void;

export abstract class Base {
  protected fireEvent: Handler;
  protected visitor: Visitor;

  public constructor(handler: Handler, visitor: Visitor) {
    this.fireEvent = handler;
    this.visitor = visitor;
  }

  public abstract init(): void;
}
