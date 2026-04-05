import { Controller } from '@hotwired/stimulus';
import { debounce } from '../utils/debounce';

type SearchState = {
  focused: boolean;
  selectionEnd: number | null;
  selectionStart: number | null;
  value: string;
};

export default class extends Controller<HTMLDivElement> {
  static targets = ['clear', 'form', 'input'];
  static values = {
    minChars: { type: Number, default: 2 }
  };

  declare readonly clearTarget: HTMLButtonElement;
  declare readonly hasClearTarget: boolean;
  declare readonly formTarget: HTMLFormElement;
  declare readonly hasInputTarget: boolean;
  declare readonly inputTarget: HTMLInputElement;
  declare readonly minCharsValue: number;

  private debouncedSubmit?: () => void;

  public connect(): void {
    this.debouncedSubmit = debounce(() => this.submit(), 500);
    this.syncClearButton();
    this.restoreFocus();
  }

  public queueSearch(): void {
    this.rememberFocus();
    this.syncClearButton();
    if (!this.shouldSubmit()) return;

    this.debouncedSubmit?.();
  }

  public submitNow(): void {
    this.submit();
  }

  public submitWithoutFocusRestore(): void {
    this.syncClearButton();
    if (this.hasInputTarget) {
      this.writeState({
        focused: false,
        selectionEnd: this.inputTarget.selectionEnd,
        selectionStart: this.inputTarget.selectionStart,
        value: this.inputTarget.value
      });
    }

    this.formTarget.requestSubmit();
  }

  public clear(event: Event): void {
    event.preventDefault();
    if (!this.hasInputTarget) return;
    if (this.inputTarget.value === '') return;

    this.inputTarget.value = '';
    this.writeState({
      focused: true,
      selectionEnd: 0,
      selectionStart: 0,
      value: ''
    });
    this.syncClearButton();
    this.inputTarget.focus();
    this.formTarget.requestSubmit();
  }

  public rememberBlur(): void {
    if (!this.hasInputTarget) return;

    this.writeState({
      focused: false,
      selectionEnd: this.inputTarget.selectionEnd,
      selectionStart: this.inputTarget.selectionStart,
      value: this.inputTarget.value
    });
  }

  public rememberFocus(): void {
    if (!this.hasInputTarget) return;

    this.writeState({
      focused: true,
      selectionEnd: this.inputTarget.selectionEnd,
      selectionStart: this.inputTarget.selectionStart,
      value: this.inputTarget.value
    });
  }

  private restoreFocus(): void {
    if (!this.hasInputTarget) return;

    const state = this.readState();
    if (!state?.focused || state.value !== this.inputTarget.value) return;

    window.requestAnimationFrame(() => {
      this.inputTarget.focus();
      this.syncClearButton();

      if (state.selectionStart === null || state.selectionEnd === null) return;

      this.inputTarget.setSelectionRange(state.selectionStart, state.selectionEnd);
    });
  }

  private shouldSubmit(): boolean {
    if (!this.hasInputTarget) return true;

    const query = this.inputTarget.value.trim();
    return query === '' || query.length >= this.minCharsValue || this.searchAlreadyApplied();
  }

  private searchAlreadyApplied(): boolean {
    const currentSearch = new URL(window.location.href).searchParams.get(this.inputTarget.name) || '';
    return currentSearch.trim() !== '';
  }

  private submit(): void {
    this.rememberFocus();
    this.syncClearButton();
    this.formTarget.requestSubmit();
  }

  private syncClearButton(): void {
    if (!this.hasClearTarget || !this.hasInputTarget) return;

    this.clearTarget.hidden = this.inputTarget.value.trim() === '';
  }

  private readState(): SearchState | null {
    const rawState = window.sessionStorage.getItem(this.storageKey);
    if (!rawState) return null;

    return JSON.parse(rawState) as SearchState;
  }

  private writeState(state: SearchState): void {
    window.sessionStorage.setItem(this.storageKey, JSON.stringify(state));
  }

  private get storageKey(): string {
    const action = this.formTarget.getAttribute('action') || window.location.pathname;
    const inputName = this.hasInputTarget ? this.inputTarget.name : 'search';
    return `search:${action}:${inputName}`;
  }
}
