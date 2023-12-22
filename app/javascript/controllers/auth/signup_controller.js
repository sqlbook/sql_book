import { Controller } from '@hotwired/stimulus';
import { addFormHelperEventListeners } from '../../utils/form-helpers';
import { addOtpHelperEventListeners } from '../../utils/otp-helpers';

export default class extends Controller {
  connect() {
    addFormHelperEventListeners();
    addOtpHelperEventListeners();
  }
}
