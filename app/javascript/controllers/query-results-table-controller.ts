import { Controller } from '@hotwired/stimulus';
import { QueryResult } from '../types/query-result';
import { ChartConfig } from '../types/chart-config';

export default class extends Controller<HTMLDivElement> {
  static targets = ['start', 'prev', 'next', 'end', 'currentPage', 'totalPages'];

  static values = {
    config: {},
    result: [],
  };

  private page: number = 0;

  declare readonly configValue: ChartConfig;
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

  private setPage = () => {
    this.setPageValue();
    this.setVisibleRows();
  };

  private setPageValue = () => {
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

  private setVisibleRows = () => {
    if (this.configValue.pagination_enabled) {
      const start = (this.page * this.configValue.pagination_rows);
      const end = start + Number(this.configValue.pagination_rows) - 1;

      this.element.querySelectorAll<HTMLTableRowElement>('tr:not(:first-of-type)').forEach((row, index) => {
        row.style.display = 'none';

        if (index >= start && index <= end) {
          row.style.removeProperty('display');
        }
      });
    }
  };

  private get pages() {
    return Math.ceil(this.resultValue.length / this.configValue.pagination_rows);
  }
}
