export type ClickEvent = {
  coordinates_x: number;
  coordinates_y: number;
  selector: string;
  inner_text: string | null;
  attributes_id: string | null;
  attributes_class: string | null;
}
