import { bb, bar, DataItem } from 'billboard.js';
import { Controller } from '@hotwired/stimulus';
import { ChartConfig } from '../types/chart-config';

export default class extends Controller<HTMLDivElement> {
  static values = {
    config: {},
  };

  declare readonly configValue: ChartConfig;

  public connect(): void {
    bb.generate({
      bindto: '#chart',
      data: {
        type: bar(),
        columns: [
          ["data1", 30, 200, 100, 400, 150, 250],
        ], 
      },
      axis: {
        x: {
          label: this.configValue.x_axis_label_enabled ? { 
            position: 'outer-center',
            text: this.configValue.x_axis_label,
          } : undefined,
          show: true,
        },
        y: {
          label: this.configValue.y_axis_label_enabled ? {
            position: 'outer-middle',
            text: this.configValue.y_axis_label,
          } : undefined,
          show: true,
        },
      },
      grid: {
        x: {
          show: this.configValue.x_axis_gridlines_enabled,
        },
        y: {
          show: this.configValue.y_axis_gridlines_enabled,
        },
      },
      zoom: {
        enabled: this.configValue.zooming_enabled,
      },
      tooltip: {
        show: this.configValue.tooltips_enabled,
      },
      legend: {
        show: this.configValue.legend_enabled,
        position: this.configValue.position,
      }
    });
  }
}
