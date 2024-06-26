import { ChartData } from 'chart.js';
import { QueryResult } from '../types/query-result';
import { ChartSettings } from '../types/chart-settings';
import { hexToRgb } from './utils';

type Data = { x: string, y: string }[] | number[];

export function buildData(settings: ChartSettings) {
  const data = mapDataToAxis(settings, settings.result);

  switch(settings.type) {
    case 'line':
      return buildLineData(settings, data);
    case 'area':
      return buildAreaData(settings, data);
    case 'bar':
    case 'column':
      return buildColumnData(settings, data);
    case 'doughnut':
    case 'pie':
      return buildPieData(settings);
    default:
      throw new Error(`Unsure how to build chart data for ${settings.type}`);
  }  
};

function mapDataToAxis(settings: ChartSettings, results: QueryResult): Data {
  return results.map(r => ({
    x: r[settings.config.x_axis_key],
    y: r[settings.config.y_axis_key],
  }));
}

function buildLineData(settings: ChartSettings, data: Data): { data: ChartData<'line', Data> } {
  return {
    data: {
      datasets: [
        {
          data,
          backgroundColor: settings.config.colors[0],
          borderColor: settings.config.colors[0],
          pointBackgroundColor: settings.colors.gray850,
          pointBorderColor: settings.config.colors[0],
          pointBorderWidth: 2,
        },
      ],
    },
  };
}

function buildAreaData(settings: ChartSettings, data: Data): { data: ChartData<'line', Data> } {
  return {
    data: {
      datasets: [
        {
          data,
          backgroundColor: hexToRgb(settings.config.colors[0], .25),
          borderColor: settings.config.colors[0],
          pointBackgroundColor: settings.colors.gray850,
          pointBorderColor: settings.config.colors[0],
          pointBorderWidth: 2,
          fill: 'start',
        },
      ],
    },
  };
}

function buildColumnData(settings: ChartSettings, data: Data): { data: ChartData<'bar', Data> } {
  return {
    data: {
      datasets: [
        {
          data,
          backgroundColor: settings.config.colors[0],
          borderColor: settings.config.colors[0],
          borderRadius: 4,
        },
      ],
    },
  };
}

function buildPieData(settings: ChartSettings): { data: ChartData<'pie', Data> } {
  const values = settings.result.map(r => Object.values(r));
  const firstValueIsCount = typeof values[0][0] === 'number';

  const labels = values.map(v => v[firstValueIsCount ? 1 : 0]);
  const counts = values.map(v => Number(v[firstValueIsCount ? 0 : 1]));
  
  return {
    data: {
      labels,
      datasets: [
        {
          data: counts,
          backgroundColor: settings.config.colors,
          borderColor: settings.colors.gray850,
          borderWidth: 2,
          // These are valid
          ['radius' as any]: '50%',
          ['cutout' as any]: settings.type === 'pie' ? 0 : `${settings.config.circumference}%`,
        },
      ],
    },
  };
}
