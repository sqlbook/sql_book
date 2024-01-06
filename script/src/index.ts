import { Script } from './script';

declare global {
  const HOST: string;

  interface Window {
    sqlbook: Script;
    _sbSettings: { uuid: string };
  }
}

window.sqlbook ||= new Script(window._sbSettings.uuid);
