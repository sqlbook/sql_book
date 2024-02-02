export type ChartConfig = {
  colors: string[],
  legend_enabled: boolean;
  legend_position: 'top' | 'bottom' | 'right' | 'left';
  legend_alignment: 'start' | 'center' | 'end',
  subtitle: string;
  subtitle_enabled: boolean;
  title: string;
  title_enabled: boolean;
  tooltips_enabled: boolean;
  x_axis_gridlines_enabled: boolean;
  x_axis_key: string;
  x_axis_label: string;
  x_axis_label_enabled: boolean;
  y_axis_gridlines_enabled: boolean;
  y_axis_key: string;
  y_axis_label: string;
  y_axis_label_enabled: boolean;
}
