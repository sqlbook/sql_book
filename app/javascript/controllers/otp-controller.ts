import { Controller } from '@hotwired/stimulus';

const ALLOWED_CHARACTERS = /[0-9]/;
const CODE_LENGTH = 6;

export default class extends Controller<HTMLDivElement> {
  private inputs: HTMLInputElement[] = [];

  public connect(): void {
    this.inputs = Array.from(this.element.querySelectorAll<HTMLInputElement>('.input'));

    this.inputs.forEach((element) => {
      element.addEventListener('keyup', this.onOtpInputKeyUp);
      element.addEventListener('keypress', this.onOtpInputKeyPress);
      element.addEventListener('paste', this.onOtpPaste);
      element.addEventListener('change', this.onChange);
    });
  }

  public disconnect(): void {
    this.inputs.forEach((element) => {
      element.removeEventListener('keyup', this.onOtpInputKeyUp);
      element.removeEventListener('keypress', this.onOtpInputKeyPress);
      element.removeEventListener('paste', this.onOtpPaste);
      element.removeEventListener('change', this.onChange);
    });

    this.inputs = [];
  }

  private onOtpInputKeyUp = (event: KeyboardEvent): void => {
    const target = event.target as HTMLInputElement;
    const next = target?.nextElementSibling as HTMLInputElement | null;

    if (ALLOWED_CHARACTERS.test(event.key) && next) {
      next.focus();
    }
  };

  private onOtpInputKeyPress = (event: KeyboardEvent): void => {
    if (!ALLOWED_CHARACTERS.test(event.key)) {
      event.preventDefault();
    }
  };
  
  private onOtpPaste = (event: ClipboardEvent): void => {
    if (!event.clipboardData) return;

    const code = event.clipboardData.getData('text').replace(/\D/g, '').slice(0, CODE_LENGTH);

    if (code.length === CODE_LENGTH) {
      event.preventDefault();
      this.autofillCode(code);
    }
  };

  private onChange = (event: Event): void => {
    const target = event.target as HTMLInputElement;
    const code = target.value.replace(/\D/g, '').slice(0, CODE_LENGTH);

    // Handle Safari autofill
    if (code.length === CODE_LENGTH) {
      this.autofillCode(code);
    }
  };

  private autofillCode(code: string): void {
    this.inputs.forEach((element, index) => {
      element.value = code[index];
    });

    this.element.closest('form')?.dispatchEvent(new Event('input', { bubbles: true }));
  }
}
