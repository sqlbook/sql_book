import { ClickEvent } from './click';
import { PageViewEvent } from './page-view';
import { SessionEvent } from './session';

export type EventType = 'click' | 'page_view' | 'session';

export type Event = ClickEvent | PageViewEvent | SessionEvent;
