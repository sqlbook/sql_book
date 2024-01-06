export type SessionEvent = {
  viewport_x: number;
  viewport_y: number;
  device_x: number;
  device_y: number;
  referrer?: string;
  locale?: string;
  useragent?: string;
  browser?: string;
  device_type?: string;
  timezone?: string;
  country_code?: string;
  utm_source?: string;
  utm_medium?: string;
  utm_campaign?: string;
  utm_content?: string;
  utm_term?: string;
}
