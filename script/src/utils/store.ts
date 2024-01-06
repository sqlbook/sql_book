import { StoreState } from '../types/store';

class Store {
  STORE_KEY = 'sqlbook';

  private state: StoreState;

  public constructor() {
    this.state = this.getOrCreateStore();
  }

  public get(key: keyof StoreState): string | null {
    return this.state[key];
  }

  public set(key: keyof StoreState, value: string): string {
    this.setStore({ ...this.state, [key]: value });
    return value;
  }

  private getOrCreateStore(): StoreState {
    const store = this.getStore();

    const fallback: StoreState = {
      lastEventAt: null,
      sessionUuid: null,
      visitorUuid: null,
    };

    return this.setStore(store || fallback);
  }

  private getStore(): StoreState | null {
    try {
      const store = localStorage.getItem(this.STORE_KEY);

      if (!store) return null;

      return JSON.parse(atob(store)) as StoreState;
    } catch(error) {
      console.error('Failed to decode store', error);
      return null;
    }
  }

  private setStore(store: StoreState): StoreState {
    try {
      localStorage.setItem(this.STORE_KEY, btoa(JSON.stringify(store)));
    } catch(error) {
      console.error('Failed to set store', error);
    }

    return store;
  }
}

export const store = new Store();
