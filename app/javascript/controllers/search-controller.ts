import { Controller } from '@hotwired/stimulus';
import { debounce } from '../utils/debounce';

type SearchState = {
  focused: boolean;
  selectionEnd: number | null;
  selectionStart: number | null;
  value: string;
};

export default class extends Controller<HTMLDivElement> {
  static targets = ['form', 'input'];
  static values = {
    minChars: { type: Number, default: 2 }
  };

  declare readonly formTarget: HTMLFormElement;
  declare readonly hasInputTarget: boolean;
  declare readonly inputTarget: HTMLInputElement;
  declare readonly minCharsValue: number;

  private debouncedSubmit?: () => void;

  public connect(): void {
    this.debouncedSubmit = debounce(() => this.submit(), 500);
    this.restoreFocus();
  }

  public queueSearch(): void {
    this.rememberFocus();
    if (!this.shouldSubmit()) return;

    this.debouncedSubmit?.();
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
    this.formTarget.requestSubmit();
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
