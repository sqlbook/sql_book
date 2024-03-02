import { Consumer, Subscription, createConsumer } from '@rails/actioncable';
import { Click, PageView, Session } from './listeners';
import { Visitor } from './utils/visitor';
import { EventType, Event } from './types/events/event';
import { store } from './utils/store';

export class Script {
  private visitor: Visitor;
  private dataSourceUuid: string;

  private consumer!: Consumer;
  private subscription!: Subscription<Consumer>;

  private listeners = [
    Click,
    PageView,
    Session,
  ];

  public constructor(dataSourceUuid: string) {
    this.dataSourceUuid = dataSourceUuid;
    this.visitor = new Visitor(dataSourceUuid);

    this.consumer = createConsumer(`${this.websocketUrl}?${this.visitor.params.toString()}`);

    this.subscription = this.consumer.subscriptions.create('EventChannel', {
      connected: () => {
        this.listeners.forEach(listener => {
          new listener(this.onEvent, this.visitor).init()
        });
      },
    });
  }

  private onEvent = (type: EventType, event: Event) => {
    store.set('lastEventAt', new Date().toISOString());

    this.subscription.perform('event', {
      ...event,
      type,
      visitor_uuid: this.visitor.visitorUuid,
      session_uuid: this.visitor.sessionUuid,
      data_source_uuid: this.dataSourceUuid,
      timestamp: Math.floor(new Date().valueOf() / 1000),
    });
  };

  private get websocketUrl() {
    try {
      return process.env.WEBSOCKET_URL;
    } catch {
      return 'ws://localhost:3000/events/in';
    }
  }
}
