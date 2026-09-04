import React, {type JSX} from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';
import type {CellValue, QueryTraceProps, TraceStep} from './types';

export type {QueryTraceProps, TraceStep} from './types';

function fmt(v: CellValue): string {
  if (v === null) return 'NULL';
  if (v === true) return 'true';
  if (v === false) return 'false';
  return String(v);
}

function opSet(op?: string | string[]): Set<string> {
  if (!op) return new Set();
  return new Set(Array.isArray(op) ? op : [op]);
}

function rowClass(index: number, marks?: TraceStep['rows']): string | undefined {
  if (!marks) return undefined;
  if (marks.drop?.includes(index)) return styles.rowDrop;
  if (marks.add?.includes(index)) return styles.rowAdd;
  if (marks.match?.includes(index)) return styles.rowMatch;
  return undefined;
}

function StepTable({step}: {step: TraceStep}): JSX.Element {
  const {table} = step;
  const ops = opSet(step.op);
  const nullCol = (c: string) => (v: CellValue) =>
    v === null ? styles.cellNull : undefined;

  // Build the ordered list of [rowIndex, groupLabel?] to render.
  const ordered: {idx: number; groupStart?: string | null}[] = [];
  if (step.groups && step.groups.length > 0) {
    step.groups.forEach((g, gi) => {
      g.rows.forEach((idx, ri) => {
        ordered.push({idx, groupStart: ri === 0 ? g.label ?? `group ${gi + 1}` : undefined});
      });
    });
  } else {
    table.rows.forEach((_, idx) => ordered.push({idx}));
  }

  return (
    <figure className={styles.figure}>
      <figcaption className={styles.stepTitle}>{step.title}</figcaption>
      {step.note && <p className={styles.stepNote}>{step.note}</p>}
      <div className={styles.scroll}>
        <table
          className={clsx(styles.grid, table.result && styles.resultGrid)}
          data-table-name={table.name}
        >
          {table.name && (
            <caption className={styles.tableName}>
              {table.name}
              {table.result && <span className={styles.resultTag}>result</span>}
            </caption>
          )}
          <thead>
            <tr>
              {step.groups && <th className={styles.gutter} aria-label="group" />}
              {table.columns.map((col) => (
                <th key={col} className={clsx(ops.has(col) && styles.opCol)}>
                  {col}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {ordered.map(({idx, groupStart}, renderPos) => {
              const row = table.rows[idx] ?? [];
              return (
                <tr
                  key={idx}
                  className={clsx(
                    rowClass(idx, step.rows),
                    groupStart !== undefined && styles.groupFirst,
                  )}
                >
                  {step.groups && (
                    <td className={styles.gutter}>
                      {groupStart !== undefined ? (
                        <span className={styles.groupLabel}>{groupStart}</span>
                      ) : null}
                    </td>
                  )}
                  {table.columns.map((col, ci) => {
                    const value = row[ci] ?? null;
                    return (
                      <td
                        key={col}
                        className={clsx(
                          ops.has(col) && styles.opCol,
                          nullCol(col)(value),
                        )}
                      >
                        {fmt(value)}
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </figure>
  );
}

/**
 * QueryTrace — a step-by-step hand-trace of a query on real rows.
 *
 * v1 renders every step stacked vertically, each with its own table, the
 * operated column accented and dropped/added/matched rows tinted.
 *
 * v2 seam: the `steps` array is already an animation timeline. A future
 * `mode="step"` prop can show one step at a time with Prev/Next controls and
 * cell transitions — no page or data changes required.
 */
export default function QueryTrace({caption, steps}: QueryTraceProps): JSX.Element {
  return (
    <section className={styles.trace} aria-label={caption ?? 'query hand-trace'}>
      {caption && <p className={styles.caption}>{caption}</p>}
      <ol className={styles.steps}>
        {steps.map((step, i) => (
          <li key={i}>
            <StepTable step={step} />
            {i < steps.length - 1 && <div className={styles.arrow} aria-hidden="true" />}
          </li>
        ))}
      </ol>
    </section>
  );
}
