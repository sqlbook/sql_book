export class Colors {
  public get gray900(): string {
    return this.isDarkMode ? '#111111' : '#ECE9E1';
  }

  public get gray850(): string {
    return this.isDarkMode ? '#1C1C1C' : '#F5F2E7';
  }

  public get gray800(): string {
    return this.isDarkMode ? '#222222' : '#FAF9F6';
  }

  public get gray700(): string {
    return this.isDarkMode ? '#333333' : '#CCCCCC';
  }

  public get gray500(): string {
    return this.isDarkMode ? '#777777' : '#BBBBBB';
  }

  public get gray300(): string {
    return this.isDarkMode ? '#A1A1A1' : '#A1A1A1';
  }

  public get gray250(): string {
    return this.isDarkMode ? '#BBBBBB' : '#777777';
  }

  public get gray200(): string {
    return this.isDarkMode ? '#CCCCCC' : '#333333';
  }

  public get red700(): string {
    return this.isDarkMode ? '#FF4941' : '#FF4941';
  }

  public get red600(): string {
    return this.isDarkMode ? '#FF6A64' : '#F5807B';
  }

  public get red500(): string {
    return this.isDarkMode ? '#F5807B' : '#FF6A64';
  }

  public get red300(): string {
    return this.isDarkMode ? '#FF9995' : '#FF9995';
  }

  public get cream250(): string {
    return this.isDarkMode ? '#ECE9E1' : '#111111';
  }

  public get cream200(): string {
    return this.isDarkMode ? '#F5F2E7' : '#1C1C1C';
  }

  public get cream100(): string {
    return this.isDarkMode ? '#FAF9F6' : '#222222';
  }

  public get white(): string {
    return this.isDarkMode ? '#000000' : '#FFFFFF';
  }

  private get isDarkMode(): boolean {
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  }  
}
