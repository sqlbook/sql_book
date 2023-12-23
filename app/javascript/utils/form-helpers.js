/**
 * Check all of the required inputs in a form and enable
 * or disable the submit button based on the validity
 * @returns {void}
 */
export function addFormHelperEventListeners() {
  const form = document.querySelector('form');

  if (!form) return;

  const button = form.querySelector('input[type="submit"]');

  // Set the initial value
  setButtonDisabled(form, button);

  form.addEventListener('input', () => {
    setButtonDisabled(form, button)
  });
}

/**
 * @param {HTMLFormElement} form 
 * @param {HTMLInputElement} button 
 * @returns {void}
 */
function setButtonDisabled(form, button) {
  if (form.checkValidity()) {
    button.removeAttribute('disabled');
  } else {
    button.setAttribute('disabled', 'true');
  }
}
