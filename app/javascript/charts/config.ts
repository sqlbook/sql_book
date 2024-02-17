import { ChartConfig } from '../types/chart-config';

export function buildConfig(type: string, config: ChartConfig) {
  return {
    options: {
      indexAxis: indexAxis(type),
      plugins: {
        tooltip: {
          enabled: config.tooltips_enabled,
        },
        legend: {
          display: config.legend_enabled,
          position: config.legend_position,
          align: config.legend_alignment,
          labels: {
            color: '#BBBBBB',
            boxHeight: 16,
            boxWidth: 16,
          }
        },
      },
      scales: {
        x: {
          title: {
            color: '#CCCCCC',
            display: config.x_axis_label_enabled,
            text: config.x_axis_label,
          },
          grid: {
            color: '#333333',
            drawTicks: false,
            display: config.x_axis_gridlines_enabled,
          },
          ticks: {
            color: '#BBBBBB',
          },
        },
        y: {
          title: {
            color: '#BBBBBB',
            display: config.y_axis_label_enabled,
            text: config.y_axis_label,
          },
          grid: {
            color: '#333333',
            drawTicks: false,
            display: config.y_axis_gridlines_enabled,
          },
          ticks: {
            color: '#BBBBBB',
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
