const ALLOWED_CHARACTERS = /[0-9]/;

/**
 * Skip to the next input when a valid character is entered
 * @param {Event} event 
 * @returns {void}
 */
export function onOtpInputKeyUp(event) {
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
export function onOtpInputKeyPress(event) {
  if (!ALLOWED_CHARACTERS.test(event.key)) {
    event.preventDefault();
  }
}

/**
 * Paste the individual parts of the token into the inputs
 * @param {ClipboardEvent} event 
 * @returns {void}
 */
export function onOtpPaste(event) {
  console.log('!!')
  const code = event.clipboardData.getData('text');

  console.log(code);

  if (code.length === 6) {
    document.querySelectorAll('.otp-code .input').forEach((element, index) => {
      element.value = code[index];
    });

    event.target.blur();
  }
}
