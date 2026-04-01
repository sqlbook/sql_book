import { Controller } from '@hotwired/stimulus';
import { QueryResult } from '../types/query-result';

export default class extends Controller<HTMLDivElement> {
  static targets = ['start', 'prev', 'next', 'end', 'currentPage', 'totalPages'];

  static values = {
    pageSize: Number,
    result: [],
  };

  private page: number = 0;

  declare readonly pageSizeValue: number;
  declare readonly resultValue: QueryResult;

  declare readonly startTarget: HTMLButtonElement;
  declare readonly prevTarget: HTMLButtonElement;
  declare readonly nextTarget: HTMLButtonElement;
  declare readonly endTarget: HTMLButtonElement;

  declare readonly currentPageTarget: HTMLSpanElement;
  declare readonly totalPagesTarget: HTMLSpanElement;

  public connect() {
    this.setPage();
  }

  public start(): void {
    this.page = 0;
    this.setPage();
  }

  public prev(): void {
    if (this.page > 0) {
      this.page -= 1;
      this.setPage();
    }
  }

  public next(): void {
    if (this.page < this.pages - 1) {
      this.page += 1;
      this.setPage();
    }
  }

  public end(): void {
    this.page = this.pages - 1;
    this.setPage();
  }

  private setPage = (): void => {
    this.setPageValue();
    this.setVisibleRows();
  };

  private setPageValue = (): void => {
    this.currentPageTarget.innerText = (this.page + 1).toString();
    this.totalPagesTarget.innerText = this.pages.toString();

    this.startTarget.classList.remove('disabled');
    this.prevTarget.classList.remove('disabled');
    this.nextTarget.classList.remove('disabled');
    this.endTarget.classList.remove('disabled');

    if (this.page === 0) {
      this.startTarget.classList.add('disabled');
      this.prevTarget.classList.add('disabled');
    }

    if (this.page === this.pages - 1) {
      this.nextTarget.classList.add('disabled');
      this.endTarget.classList.add('disabled');
    }
  }

  private setVisibleRows = (): void => {
    if (this.pageSizeValue > 0) {
      const start = this.page * this.pageSizeValue;
      const end = start + this.pageSizeValue - 1;

      this.element.querySelectorAll<HTMLTableRowElement>('tr:not(:first-of-type)').forEach((row, index) => {
        row.style.display = 'none';

        if (index >= start && index <= end) {
          row.style.removeProperty('display');
        }
      });
    }
  };

  private get pages(): number {
    return Math.max(1, Math.ceil(this.resultValue.length / this.pageSizeValue));
  }
}
