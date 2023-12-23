import { Controller } from '@hotwired/stimulus';
import { addCopyToClipboardListeners } from '../../utils/copy-to-clipboard-helpers';
import { addFormHelperEventListeners } from '../../utils/form-helpers';

export default class extends Controller {
  connect() {
    addCopyToClipboardListeners();
    addFormHelperEventListeners();
  }
}
