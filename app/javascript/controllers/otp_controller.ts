import { Controller } from '@hotwired/stimulus';

const ALLOWED_CHARACTERS = /[0-9]/;

export default class extends Controller<HTMLDivElement> {
  connect(): void {
    document.querySelectorAll<HTMLInputElement>('.otp-code .input').forEach((element) => {
      element.addEventListener('keyup', this.onOtpInputKeyUp);
      element.addEventListener('keypress', this.onOtpInputKeyPress);
      element.addEventListener('paste', this.onOtpPaste);
    });
  }

  onOtpInputKeyUp = (event: KeyboardEvent): void => {
    const target = event.target as HTMLInputElement;
    const next = target?.nextElementSibling as HTMLInputElement | null;

    if (ALLOWED_CHARACTERS.test(event.key) && next) {
      next.focus();
    }
  }

  onOtpInputKeyPress = (event: KeyboardEvent): void => {
    if (!ALLOWED_CHARACTERS.test(event.key)) {
      event.preventDefault();
    }
  }
  
  onOtpPaste = (event: ClipboardEvent): void => {
    if (!event.clipboardData) return;

    const code = event.clipboardData.getData('text');

    if (code.length === 6) {
      document.querySelectorAll<HTMLInputElement>('.otp-code .input').forEach((element, index) => {
        element.value = code[index];
      });
    }
  }
}
