import { Controller } from '@hotwired/stimulus';

const ALLOWED_CHARACTERS = /[0-9]/;

export default class extends Controller {
  connect() {
    document.querySelectorAll('.otp-code .input').forEach(element => {
      element.addEventListener('keyup', event => this.onOtpInputKeyUp(event));
      element.addEventListener('keypress', event => this.onOtpInputKeyPress(event));
      element.addEventListener('paste', event => this.onOtpPaste(event));
    });
  }

  onOtpInputKeyUp(event) {
    const next = event.target.nextElementSibling;

    if (ALLOWED_CHARACTERS.test(event.key) && next) {
      next.focus();
    }
  }

  onOtpInputKeyPress(event) {
    if (!ALLOWED_CHARACTERS.test(event.key)) {
      event.preventDefault();
    }
  }
  
  onOtpPaste(event) {
    const code = event.clipboardData.getData('text');

    if (code.length === 6) {
      document.querySelectorAll('.otp-code .input').forEach((element, index) => {
        element.value = code[index];
      });
    }
  }
}
