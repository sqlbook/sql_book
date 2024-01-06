export type SessionEvent = {
  viewport_x: number;
  viewport_y: number;
  device_x: number;
  device_y: number;
  referrer: string | null;
  locale: string | null;
  useragent: string | null;
  timezone: string | null;
  utm_source: string | null;
  utm_medium: string | null;
  utm_campaign: string | null;
  utm_content: string | null;
  utm_term: string | null;
}
