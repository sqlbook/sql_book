import Chart, { ChartType } from 'chart.js/auto';
import { Controller } from '@hotwired/stimulus';
import { ChartConfig } from '../types/chart-config';
import { QueryResult } from '../types/query-result';

export default class extends Controller<HTMLCanvasElement> {
  static values = {
    config: {},
    result: [],
  };

  declare readonly configValue: ChartConfig;
  declare readonly resultValue: QueryResult;

  // TODO: 
  // - zooming_enabled
  // - colors won't work in light mode

  // For each of the supported chart types, return some cofig that needs to be deep merged

  public connect(): void {
    new Chart(this.element, {
      type: 'bar',
      data: {
        datasets: [
          {
            data: this.mappedDataToAxis,
            backgroundColor: this.configValue.colors[0],
            borderRadius: 4,
          },
        ],
      },
      options: {
        indexAxis: 'y',
        plugins: {
          tooltip: {
            enabled: this.configValue.tooltips_enabled,
          },
          legend: {
            display: this.configValue.legend_enabled,
            position: this.configValue.legend_position,
            align: this.configValue.legend_alignment,
          },
        },
        scales: {
          x: {
            title: {
              color: '#CCCCCC',
              display: this.configValue.x_axis_label_enabled,
              text: this.configValue.x_axis_label,
            },
            grid: {
              color: '#333333',
              drawTicks: false,
              display: this.configValue.x_axis_gridlines_enabled,
            },
            ticks: {
              color: '#BBBBBB',
            },
          },
          y: {
            title: {
              color: '#BBBBBB',
              display: this.configValue.y_axis_label_enabled,
              text: this.configValue.y_axis_label,
            },
            grid: {
              color: '#333333',
              drawTicks: false,
              display: this.configValue.y_axis_gridlines_enabled,
            },
            ticks: {
              color: '#BBBBBB',
            },
          }
        },
      },
    });
  }

  private get mappedDataToAxis(): { x: string, y: string }[] {
    return this.resultValue.map(r => ({
      x: r[this.configValue.x_axis_key],
      y: r[this.configValue.y_axis_key],
    }));
  }
}
