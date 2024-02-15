import { ChartConfig } from '../types/chart-config';

export const buildConfig = (config: ChartConfig) => ({
  options: {
    plugins: {
      tooltip: {
        enabled: config.tooltips_enabled,
      },
      legend: {
        display: config.legend_enabled,
        position: config.legend_position,
        align: config.legend_alignment,
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
});
