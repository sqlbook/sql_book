import { ChartData } from 'chart.js';
import { ChartConfig } from '../types/chart-config';
import { QueryResult } from '../types/query-result';
import { hexToRgb } from './utils';

type Data = { x: string, y: string }[];

export function buildData(type: string, config: ChartConfig, result: QueryResult) {
  const data = mapDataToAxis(config, result);

  switch(type) {
    case 'line':
      return buildLineData(config, data);
    case 'area':
      return buildAreaData(config, data);
    case 'column':
    case 'bar':
      return buildColumnData(config, data);
    case 'pie':
    case 'donut':
      return buildPieData(config, result);
    default:
      throw new Error(`Unsure how to build chart data for ${type}`);
  }  
};

function mapDataToAxis(config: ChartConfig, results: QueryResult): Data {
  return results.map(r => ({
    x: r[config.x_axis_key],
    y: r[config.y_axis_key],
  }));
}

function buildLineData(config: ChartConfig, data: Data): { data: ChartData<'line', Data> } {
  return {
    data: {
      datasets: [
        {
          data,
          backgroundColor: config.colors[0],
          borderColor: config.colors[0],
          pointBackgroundColor: '#1C1C1C',
          pointBorderColor: config.colors[0],
          pointBorderWidth: 2,
        },
      ],
    },
  };
}

function buildAreaData(config: ChartConfig, data: Data): { data: ChartData<'line', Data> } {
  return {
    data: {
      datasets: [
        {
          data,
          backgroundColor: hexToRgb(config.colors[0], .25),
          borderColor: config.colors[0],
          pointBackgroundColor: '#1C1C1C',
          pointBorderColor: config.colors[0],
          pointBorderWidth: 2,
          fill: 'start',
        },
      ],
    },
  };
}

function buildColumnData(config: ChartConfig, data: Data): { data: ChartData<'bar', Data> } {
  return {
    data: {
      datasets: [
        {
          data,
          backgroundColor: config.colors[0],
          borderColor: config.colors[0],
          borderRadius: 4,
        },
      ],
    },
  };
}

function buildPieData(config: ChartConfig, result: QueryResult): { data: ChartData<'pie', number[]> } {
  const values = result.map(r => Object.values(r));
  const firstValueIsCount = typeof values[0][0] === 'number';
  
  const labels = values.map(v => v[firstValueIsCount ? 1 : 0]);
  const counts = values.map(v => Number(v[firstValueIsCount ? 0 : 1]));
  
  return {
    data: {
      labels,
      datasets: [
        {
          data: counts,
          backgroundColor: config.colors,
          borderColor: '#1C1C1C',
          borderWidth: 2,
          radius: '50%',
        },
      ],
    },
  };
}
