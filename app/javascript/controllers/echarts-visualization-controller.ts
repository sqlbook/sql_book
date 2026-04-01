import { Controller } from '@hotwired/stimulus';
import { EChartsType } from 'echarts/core';
import { echarts } from '../charts/echarts';

type EChartsPayload = Record<string, unknown> | null;

export default class extends Controller<HTMLDivElement> {
  static values = {
    darkOption: Object,
    lightOption: Object,
    darkTheme: Object,
    lightTheme: Object,
    mode: String,
  };

  declare readonly darkOptionValue: EChartsPayload;
  declare readonly lightOptionValue: EChartsPayload;
  declare readonly darkThemeValue: Record<string, unknown>;
  declare readonly lightThemeValue: Record<string, unknown>;
  declare readonly hasModeValue: boolean;
  declare readonly modeValue: string;

  private chart: EChartsType | null = null;
  private resizeObserver: ResizeObserver | null = null;
  private mediaQuery: MediaQueryList | null = null;
  private instanceKey = `visualization-${Math.random().toString(36).slice(2)}`;

  connect(): void {
    this.mediaQuery = window.matchMedia('(prefers-color-scheme: light)');
    this.mediaQuery.addEventListener('change', this.handleModeChange);
    this.resizeObserver = new ResizeObserver(() => this.chart?.resize());
    this.resizeObserver.observe(this.element);
    this.renderChart();
  }

  disconnect(): void {
    this.mediaQuery?.removeEventListener('change', this.handleModeChange);
    this.resizeObserver?.disconnect();
    this.chart?.dispose();
    this.chart = null;
  }

  private renderChart(): void {
    const option = this.currentOption;
    if (!option) return;

    const themeName = this.themeName;
    echarts.registerTheme(themeName, this.currentTheme);

    this.chart?.dispose();
    this.chart = echarts.init(this.element, themeName);
    this.chart.setOption(option);
  }

  private handleModeChange = (): void => {
    this.renderChart();
  };

  private get currentMode(): 'dark' | 'light' {
    if (this.hasModeValue) {
      return this.modeValue === 'light' ? 'light' : 'dark';
    }

    return this.mediaQuery?.matches ? 'light' : 'dark';
  }

  private get currentOption(): EChartsPayload {
    return this.currentMode === 'light' ? this.lightOptionValue : this.darkOptionValue;
  }

  private get currentTheme(): Record<string, unknown> {
    return this.currentMode === 'light' ? this.lightThemeValue : this.darkThemeValue;
  }

  private get themeName(): string {
    return `sqlbook-${this.currentMode}-${this.instanceKey}`;
  }
}
