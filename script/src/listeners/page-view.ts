import { Base } from './base';

export class PageView extends Base {
  private previousPathname?: string;
  private timer!: ReturnType<typeof setTimeout>;

  public init() {
    this.pollForPageChanges();
  }

  private onPageView = (url: string) => {
    this.fireEvent('page_view', { url });
  };

  private pollForPageChanges(): void {
    this.poll(() => {
      if (location.pathname !== this.previousPathname) {
        this.previousPathname = location.pathname;
        this.onPageView(location.href);
      }
    });
  }

  private poll(callback: Function, interval = 500): void {
    window.clearTimeout(this.timer);

    this.timer = setTimeout(() => {
      callback();
      this.poll(callback, interval);
    }, interval);
  }
}
