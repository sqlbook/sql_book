import { Base } from './base';

export class Click extends Base {
  public init() {
    document.addEventListener('click', this.onClick);
  }

  private onClick = (event: MouseEvent): void => {
    const element = event.target as HTMLElement;

    if (!element) return;

    this.fireEvent('click', {
      coordinates_x: event.clientX,
      coordinates_y: event.clientY,
      xpath: 'TODO',
      attributes_class: element.getAttribute('class'),
      attributes_id: element.getAttribute('id'),
      inner_text: this.innerText(element),
    });
  }

  private innerText(element: Element): string | null {
    const textContent = element.textContent;

    if (!textContent) return null;

    const text = textContent.trim().substring(0, 50);

    if (text.length === textContent.length) {
      return text;
    }

    return `${text}...`;
  }
}
