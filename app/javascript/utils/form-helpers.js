/**
 * Check all of the required inputs in a form and enable
 * or disable the submit button based on the validity
 * @returns {void}
 */
export function addFormHelperEventListeners() {
  const form = document.querySelector('form');
  const button = form.querySelector('input[type="submit"]');

  form.addEventListener('input', () => {
    if (form.checkValidity()) {
      button.removeAttribute('disabled');
    } else {
      button.setAttribute('disabled', 'true');
    }
  });
}
