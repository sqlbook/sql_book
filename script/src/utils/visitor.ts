import { store } from './store';
import { StoreState } from '../types/store';

export class Visitor {
  private SESSION_CUT_OFF_MS = 1000 * 60 * 30; // 30 minutes

  public dataSourceUuid: string;

  public visitorUuid: string;
  public sessionUuid: string;

  public newVisitor: boolean;
  public newSession: boolean;

  public constructor(dataSourceUuid: string) {
    const [visitorUuid, newVisitor] = this.getOrCreateId('visitorUuid');
    const [sessionUuid, newSession] = this.getOrCreateId('sessionUuid');

    this.dataSourceUuid = dataSourceUuid;

    this.visitorUuid = visitorUuid;
    this.sessionUuid = sessionUuid;

    this.newVisitor = newVisitor;
    this.newSession = newSession;
  }

  public params() {
    return new URLSearchParams({
      visitor_uuid: this.visitorUuid,
      session_uuid: this.sessionUuid,
      data_source_uuid: this.dataSourceUuid,
    });
  }

  private get lastEventAt(): Date | null {
    const lastEventAt = store.get('lastEventAt');

    if (lastEventAt) {
      return new Date(lastEventAt);
    }

    return null;
  }

  private get shouldStartNewSession(): boolean {
    const now = new Date().valueOf();

    if (this.lastEventAt === null) {
      return false;
    }

    return (now - this.lastEventAt.valueOf()) > this.SESSION_CUT_OFF_MS;
  }

  private getOrCreateId(key: keyof Pick<StoreState, 'visitorUuid' | 'sessionUuid'>): [string, boolean] {
    let id = store.get(key);

    if (key === 'sessionUuid' && this.shouldStartNewSession) {
      id = null;
    }

    if (id) {
      return [id, false];
    }

    id = crypto.randomUUID();
    store.set(key, id);

    return [id, true];
  }
}
