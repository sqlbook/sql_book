import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLBodyElement> {
  private shortCutElements: HTMLElement[] = [];

  public connect(): void {
    this.attachShortcutEventListeners();
  }

  public disconnect(): void {
    this.dettachShortcutEventListeners();
  }

  private attachShortcutEventListeners() {
    document.querySelectorAll<HTMLElement>('*[data-shortcut]').forEach(element => {
      this.addShortcutIndicator(element);
      this.shortCutElements.push(element);
    });

    document.addEventListener('keydown', this.onShortcutPress);
  }

  private dettachShortcutEventListeners() {
    document.removeEventListener('keydown', this.onShortcutPress, true);
  }

  private addShortcutIndicator(element: HTMLElement) {
    const shortcut = element.getAttribute('data-shortcut');
    const html = element.innerHTML;

    if (shortcut && html) {
      const index = html.indexOf(shortcut);
      const parts = [html.slice(0, index), html.slice(index + 1)];

      element.innerHTML = parts.join(`<span style="text-decoration:underline">${shortcut}</span>`);
    }
  }

  private onShortcutPress = (event: KeyboardEvent) => {
    const key = event.key;
    const element = (event.target as HTMLElement).nodeName.toLowerCase();

    // Ignore if the key is pressed inside a focussable element
    if (!['input', 'select', 'button', 'textarea'].includes(element)) {
      this.clickElementWithKey(key);
    }
  };

  private clickElementWithKey = (key: string) => {
    const element = this.shortCutElements.find(element => {
      return element.getAttribute('data-shortcut')?.toLowerCase() === key.toLowerCase();
    });

    element?.click();
  };
}
