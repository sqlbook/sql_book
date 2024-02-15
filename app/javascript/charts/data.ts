import { ChartConfig } from '../types/chart-config';
import { hexToRgb } from './utils';

type Data = { x: string, y: string }[];

export const buildData = (type: string, config: ChartConfig, data: Data) => {
  switch(type) {
    case 'line':
      return buildLineData(config, data);
    case 'area':
      return buildAreaData(config, data);
    case 'column':
      return buildColumnData(config, data);
    default:
      throw new Error(`Unsure how to build chart data for ${type}`);
  }  
};

const buildLineData = (config: ChartConfig, data: Data) => ({
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
});

const buildAreaData = (config: ChartConfig, data: Data) => ({
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
});

const buildColumnData = (config: ChartConfig, data: Data) => ({
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
});
