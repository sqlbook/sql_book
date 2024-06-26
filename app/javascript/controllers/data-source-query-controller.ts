import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLDivElement> {
  static targets = ['form', 'input', 'submit', 'schema', 'queryLibrary'];

  declare readonly formTarget: HTMLFormElement;
  declare readonly inputTarget: HTMLTextAreaElement;
  declare readonly submitTarget: HTMLButtonElement;
  declare readonly schemaTarget: HTMLDivElement;
  declare readonly queryLibraryTarget: HTMLDivElement;

  public connect(): void {
    this.setButtonDisabled('');
    this.setInputRows();
  }

  public change(event: InputEvent): void {
    this.setInputRows();
    this.showQueryLibrary(event);
  }

  public changeSource(event: Event): void {
    const target = event.target as HTMLSelectElement;
    
    const parts = location.pathname.split('/');

    // Replace the data_source_id
    parts[5] = target.value;

    window.Turbo.visit(parts.join('/'), { action: 'replace' })
  }

  public changeSchema(event: Event): void {
    const target = event.target as HTMLSelectElement;
    
    document.querySelectorAll('.schema-table table').forEach((table) => {
      if (table.classList.contains(`schema-table-${target.value}`)) {
        table.classList.remove('hide');
      } else {
        table.classList.add('hide');
      }
    });
  }

  public submit(event: Event): void {
    if (!event.target) return;

    const target = event.target as HTMLTextAreaElement;
    
    if (this.isMaybeValidForm(target.value)) {
      this.formTarget.requestSubmit();
    }
  }

  public toggleSchema(event: Event): void {
    const target = event.target as HTMLElement;
    const button = target.closest('button');

    this.schemaTarget.classList.toggle('hide');

    if (button) {
      button.classList.toggle('active');
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

  private setInputRows(): void {
    const query = this.inputTarget.value;

    this.inputTarget.rows = query.split('\n').length;
    this.setButtonDisabled(query);
  }

  private showQueryLibrary(event: InputEvent): void {
    const target = event.target as HTMLInputElement;
    const searchTerm = target.value.replace('/', '').toLowerCase();

    this.queryLibraryTarget.querySelectorAll('.link').forEach(link => {
      link.classList.add('hide');
      
      if (link.textContent?.trim().toLowerCase()?.includes(searchTerm)) {
        link.classList.remove('hide');
      }
    });
    
    if (target.value.startsWith('/')) {
      this.queryLibraryTarget.classList.add('show');
    } else {
      this.queryLibraryTarget.classList.remove('show');
    }
  }
}
