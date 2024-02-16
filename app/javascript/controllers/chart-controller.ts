import Chart, { ChartType } from 'chart.js/auto';
import { Controller } from '@hotwired/stimulus';
import { ChartConfig } from '../types/chart-config';
import { QueryResult } from '../types/query-result';
import { buildConfig } from '../charts/config';
import { buildData } from '../charts/data';

export default class extends Controller<HTMLCanvasElement> {
  static values = {
    type: '',
    config: {},
    result: [],
  };

  declare readonly typeValue: string;
  declare readonly configValue: ChartConfig;
  declare readonly resultValue: QueryResult;

  public connect(): void {
    new Chart(this.element, {
      type: this.chartType,
      ...buildConfig(this.typeValue, this.configValue),
      ...buildData(this.typeValue, this.configValue, this.mappedDataToAxis),
    });
  }

  private get chartType(): ChartType {
    switch(this.typeValue) {
      case 'bar':
      case 'column':
      case 'stacked_column':
      case 'stacked_bar':
        return 'bar';
      case 'line':
      case 'area':
      case 'stacked_area':
        return 'line';
      case 'pie':
        return 'pie';
      case 'donut':
        return 'doughnut';
      default:
        throw new Error('Unknown chart type');
    }
  }

  private get mappedDataToAxis(): { x: string, y: string }[] {
    return this.resultValue.map(r => ({
      x: r[this.configValue.x_axis_key],
      y: r[this.configValue.y_axis_key],
    }));
  }
}
