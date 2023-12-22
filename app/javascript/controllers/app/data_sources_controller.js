import { Controller } from '@hotwired/stimulus';
import { addFormHelperEventListeners } from '../../utils/form-helpers';

export default class extends Controller {
  connect() {
    addFormHelperEventListeners();
  }
}
