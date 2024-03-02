import { Chart, ChartType } from 'chart.js/auto';
import { Controller } from '@hotwired/stimulus';
import { ChartConfig } from '../types/chart-config';
import { QueryResult } from '../types/query-result';
import { buildConfig } from '../charts/config';
import { buildData } from '../charts/data';
import { Colors } from '../utils/colors';
import { ChartSettings } from '../types/chart-settings';

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
      ...buildData(this.settings),
      ...buildConfig(this.settings),
    });
  }

  private get settings(): ChartSettings {
    return {
      type: this.typeValue,
      config: this.configValue,
      result: this.resultValue,
      colors: this.colors,
    };
  }

  private get colors() {
    return new Colors();
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
}
