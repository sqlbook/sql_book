import { Colors } from '../utils/colors';
import { ChartConfig } from './chart-config';
import { QueryResult } from './query-result';

export type ChartSettings = {
  type: string;
  config: ChartConfig;
  result: QueryResult;
  colors: Colors;
}
