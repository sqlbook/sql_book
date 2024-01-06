import { Application } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo-rails';

declare global {
  interface Window {
    Stimulus: Application;
    Turbo: Turbo;
  }
}


const application = Application.start();

// Configure Stimulus development experience
application.debug = false;
window.Stimulus = application;

export { application };
