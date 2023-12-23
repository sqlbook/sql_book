/**
 * Attach event listeners to any copy-to-clipboard elements
 * @returns {void}
 */
export function addCopyToClipboardListeners() {
  document.querySelectorAll('.copy-to-clipboard').forEach(element => {
    element.addEventListener('click', onCopyToClipboardClick);
  });
}

/**
 * Copy the contents to the clipboard and set a loading
 * state to make it seem like something is happening
 * @param {Event} event 
 * @returns {void}
 */
function onCopyToClipboardClick(event) {
  const source = event.target.getAttribute('data-clipboard-source');
  const originalText = event.target.innerText;

  const element = document.querySelector(`*[data-clipboard="${source}"`);

  if (element) {
    event.target.innerText = '[Copied!]';
    navigator.clipboard.writeText(element.innerText);

    setTimeout(() => event.target.innerText = originalText, 1000);
  }
}
