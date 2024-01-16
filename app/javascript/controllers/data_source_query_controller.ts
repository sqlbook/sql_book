import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['form', 'submit'];

  declare readonly formTarget: HTMLFormElement;
  declare readonly submitTarget: HTMLButtonElement;

  public connect(): void {
    this.setButtonDisabled('');
  }

  public change(event: Event): void {
    if (!event.target) return;

    const target = event.target as HTMLTextAreaElement;
    const query = target.value;

    target.rows = query.split('\n').length;
    this.setButtonDisabled(query);
  }

  public changeSource(event: Event): void {
    const target = event.target as HTMLSelectElement;
    window.Turbo.visit(`/app/data_sources/${target.value}/queries`, { action: 'replace' })
  }

  public submit(event: Event): void {
    if (!event.target) return;

    const target = event.target as HTMLTextAreaElement;
    
    if (this.isMaybeValidForm(target.value)) {
      this.formTarget.requestSubmit();
    }
  }

  private setButtonDisabled(value: string): void {    
    if (this.isMaybeValidForm(value)) {
      this.submitTarget.removeAttribute('disabled');
    } else {
      this.submitTarget.setAttribute('disabled', 'true');
    }
  }

  private isMaybeValidForm(value: string): boolean {
    if (!this.formTarget.checkValidity()) return false;

    const query = value.toLowerCase();

    return query.includes('select') && query.includes('from');
  }
}
