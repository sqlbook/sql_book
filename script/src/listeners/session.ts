import { Base } from './base';

export class Session extends Base {

  public init(): void {
    if (this.visitor.newSession) {
      this.onSession();
    }
  }

  private onSession = (): void => {
    this.fireEvent('session', {
      locale: this.locale,
      device_x: this.deviceX,
      device_y: this.deviceY,
      viewport_x: this.viewportX,
      viewport_y: this.viewportY,
      referrer: this.referrer,
      useragent: this.useragent,
      timezone: this.timezone,
      utm_campaign: this.utmCampaign,
      utm_content: this.utmContent,
      utm_medium: this.utmMedium,
      utm_source: this.utmSource,
      utm_term: this.utmTerm,
    });
  }

  private get locale(): string {
    return navigator.language || (navigator as any).userLanguage || 'zz-ZZ';
  }

  private get useragent(): string {
    return navigator.userAgent;
  }

  private get timezone(): string {
    return Intl.DateTimeFormat().resolvedOptions().timeZone;
  }

  private get deviceX(): number {
    return screen.width;
  }

  private get deviceY(): number {
    return screen.height;
  }

  private get viewportX(): number {
    return window.innerWidth;
  }

  private get viewportY(): number {
    return window.innerHeight;
  }

  private get referrer(): string | null {
    const referrer = document.referrer;

    // We don't care about referrals from their own site
    if (referrer === '' || referrer.replace('www.', '').startsWith(location.origin.replace('www.', ''))) {
      return null;
    }

    return referrer.replace(/\/$/, '');
  };

  private get utmSource(): string | null {
    return this.searchParameters.utm_source || null;
  }

  private get utmMedium(): string | null {
    return this.searchParameters.utm_medium || null;
  }

  private get utmCampaign(): string | null {
    return this.searchParameters.utm_campaign || null;
  }

  private get utmContent(): string | null {
    return this.searchParameters.utm_content || null;
  }

  private get utmTerm(): string | null {
    return this.searchParameters.utm_term || null;
  }

  private get searchParameters(): Record<string, string> {
    const parameters: Record<string, string> = {};
    const keys = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term', 'gad', 'gclid'];

    const params = new URLSearchParams(location.search);

    params.forEach((value, key) => {
      if (keys.includes(key)) {
        parameters[key] = value;
      }
    });

    return parameters;
  }
}
