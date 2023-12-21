import { Controller } from '@hotwired/stimulus';
import { onOtpInputKeyUp, onOtpInputKeyPress, onOtpPaste } from '../../utils/otp-helpers';

export default class extends Controller {
  connect() {
    document.querySelectorAll('.otp-code .input').forEach(element => {
      element.addEventListener('keyup', onOtpInputKeyUp);
      element.addEventListener('keypress', onOtpInputKeyPress);
      element.addEventListener('paste', onOtpPaste);
    });
  }
}
