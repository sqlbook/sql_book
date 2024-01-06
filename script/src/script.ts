import { Consumer, createConsumer } from '@rails/actioncable';
import { Click, PageView, Session } from './listeners';
import { Visitor } from './utils/visitor';
import { EventType, Event } from './types/events/event';

// TODO: Replace with config
const WEBSOCKET_URL = 'ws://localhost:3000/events/in';

export class Script {
  private visitor: Visitor;
  private dataSourceUuid: string;
  private consumer!: Consumer;

  private listeners = [
    Click,
    PageView,
    Session,
  ];

  public constructor(dataSourceUuid: string) {
    this.dataSourceUuid = dataSourceUuid;
    this.visitor = new Visitor(dataSourceUuid);
    this.consumer = createConsumer(`${WEBSOCKET_URL}?${this.visitor.params.toString()}`);

    this.consumer.subscriptions.create('EventChannel', {
      connected: () => {
        this.listeners.forEach(listener => {
          new listener(this.onEvent, this.visitor).init()
        });
      },
    });
  }

  private onEvent = (type: EventType, event: Event) => {
    console.log(type, {
      ...event,
      visitor_uuid: this.visitor.visitorUuid,
      session_uuid: this.visitor.sessionUuid,
      data_source_uuid: this.dataSourceUuid,
      timestamp: Math.floor(new Date().valueOf() / 1000),
    });
  };
}
