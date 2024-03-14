import { Controller } from '@hotwired/stimulus';

const ALLOWED_CHARACTERS = /[0-9]/;

export default class extends Controller<HTMLDivElement> {
  public connect(): void {
    document.querySelectorAll<HTMLInputElement>('.otp-code .input').forEach((element) => {
      element.addEventListener('keyup', this.onOtpInputKeyUp);
      element.addEventListener('keypress', this.onOtpInputKeyPress);
      element.addEventListener('paste', this.onOtpPaste);
      element.addEventListener('change', this.onChange);
    });
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

    const code = event.clipboardData.getData('text');

    if (code.length === 6) {
      this.autofillCode(code);
    }
  };

  private onChange = (event: Event): void => {
    const target = event.target as HTMLInputElement;
    const code = target.value;

    // Handle Safari autofill
    if (code.length === 6) {
      this.autofillCode(code);
    }
  };

  private autofillCode(code: string): void {
    document.querySelectorAll<HTMLInputElement>('.otp-code .input').forEach((element, index) => {
      element.value = code[index];
    });

    document.querySelector('.otp-code')?.closest('form')?.requestSubmit();
  }
}
