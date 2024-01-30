import { Controller } from '@hotwired/stimulus';
import { ChartConfig } from '../types/chart-config';
import { QueryResult } from '../types/query-result';

export default class extends Controller<HTMLDivElement> {
  static values = {
    config: {},
    result: {},
  };

  declare readonly configValue: ChartConfig;
  declare readonly resultValue: QueryResult;

  public connect(): void {

  }
}
