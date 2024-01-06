export type ClickEvent = {
  coordinates_x: number;
  coordinates_y: number;
  xpath: string;
  timestamp: number;
  inner_text?: string;
  attributes_id?: string;
  attributes_class?: string;
}
