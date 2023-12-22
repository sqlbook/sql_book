const ALLOWED_CHARACTERS = /[0-9]/;

/**
 * Add event listeners to make the otp input nicer
 * @returns {void}
 */
export function addOtpHelperEventListeners() {
  document.querySelectorAll('.otp-code .input').forEach(element => {
    element.addEventListener('keyup', onOtpInputKeyUp);
    element.addEventListener('keypress', onOtpInputKeyPress);
    element.addEventListener('paste', onOtpPaste);
  });
}

/**
 * Skip to the next input when a valid character is entered
 * @param {Event} event 
 * @returns {void}
 */
function onOtpInputKeyUp(event) {
  const next = event.target.nextElementSibling;

  if (ALLOWED_CHARACTERS.test(event.key) && next) {
    next.focus();
  }
}

/**
 * Prevent invalid characters from being entered
 * @param {Event} event 
 * @returns {void}
 */
function onOtpInputKeyPress(event) {
  if (!ALLOWED_CHARACTERS.test(event.key)) {
    event.preventDefault();
  }
}

/**
 * Paste the individual parts of the token into the inputs
 * @param {ClipboardEvent} event 
 * @returns {void}
 */
function onOtpPaste(event) {
  const code = event.clipboardData.getData('text');

  if (code.length === 6) {
    document.querySelectorAll('.otp-code .input').forEach((element, index) => {
      element.value = code[index];
    });

    event.target.blur();
  }
}
