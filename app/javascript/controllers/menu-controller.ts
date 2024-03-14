import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLMenuElement> {
  static targets = ['button', 'dropdown'];

  public toggle(): void {
    this.element.classList.toggle('open');
  }

  public changeWorkspace(event: Event): void {
    const target = event.target as HTMLSelectElement;

    // Ignore everything after the 5th position as it will have
    // a data_source_id and will not be mappable
    const parts = location.pathname.split('/').slice(0, 5);
    // Replace the workspace_id
    parts[3] = target.value;

    window.Turbo.visit(parts.join('/'), { action: 'replace' });
  }
}
