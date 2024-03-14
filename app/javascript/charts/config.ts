import { ChartOptions } from 'chart.js';
import { ChartSettings } from '../types/chart-settings';

export function buildConfig(settings: ChartSettings): { options: ChartOptions } {
  return {
    options: {
      indexAxis: indexAxis(settings.type),
      plugins: {
        tooltip: {
          enabled: settings.config.tooltips_enabled,
        },
        legend: {
          display: settings.config.legend_enabled,
          position: settings.config.legend_position,
          align: settings.config.legend_alignment,
          labels: {
            color: settings.colors.gray250,
            boxHeight: 16,
            boxWidth: 16,
          },
        },
      },
      scales: {
        x: {
          display: !['pie', 'doughnut'].includes(settings.type),
          title: {
            color: settings.colors.gray200,
            display: settings.config.x_axis_label_enabled,
            text: settings.config.x_axis_label,
          },
          grid: {
            color: settings.colors.gray700,
            drawTicks: false,
            display: settings.config.x_axis_gridlines_enabled,
          },
          ticks: {
            color: settings.colors.gray250,
          },
        },
        y: {
          display: !['pie', 'doughnut'].includes(settings.type),
          title: {
            color: settings.colors.gray250,
            display: settings.config.y_axis_label_enabled,
            text: settings.config.y_axis_label,
          },
          grid: {
            color: settings.colors.gray700,
            drawTicks: false,
            display: settings.config.y_axis_gridlines_enabled,
          },
          ticks: {
            color: settings.colors.gray250,
          },
        },
      },
    },
  };
}

function indexAxis(type: string): 'x' | 'y' | undefined {
  switch(type) {
    case 'bar':
    case 'stacked_bar':
      return 'y';
    default:
      return;
  }
}
