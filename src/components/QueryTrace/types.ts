export type CellValue = string | number | boolean | null;

export interface TraceTable {
  /** Table name shown as a small caption above the grid. */
  name?: string;
  columns: string[];
  rows: CellValue[][];
  /** Render with the "final result" border so the answer is unmistakable. */
  result?: boolean;
}

export interface TraceGroup {
  label?: string;
  /** Indices into `table.rows` that belong to this partition. */
  rows: number[];
}

export interface RowMarks {
  /** Rows removed by this step: dimmed + struck through. */
  drop?: number[];
  /** Rows introduced by this step: green tint. */
  add?: number[];
  /** Rows that matched a predicate / join: blue tint. */
  match?: number[];
}

export interface TraceStep {
  /** e.g. "2 · WHERE status = 'paid'". */
  title: string;
  /** One-line explanation of what happens to the data in this step. */
  note?: string;
  table: TraceTable;
  /** Column name(s) this step operates on — accent highlight on that column. */
  op?: string | string[];
  rows?: RowMarks;
  /** Partition the rows into groups — banded backgrounds + a label gutter. */
  groups?: TraceGroup[];
}

export interface QueryTraceProps {
  /** Shown above the whole trace. */
  caption?: string;
  steps: TraceStep[];
}
