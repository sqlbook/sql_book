import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  connect() {
    const params = new URLSearchParams(location.search);
    const verificationAttempt = Number(params.get('verification_attempt') || '0');

    if (verificationAttempt >= 5) return;

    params.set('verification_attempt', verificationAttempt + 1);

    setTimeout(() => {
      Turbo.visit(`${location.pathname}?${params.toString()}`, { action: 'replace' });
    }, 2000);
  }
}
