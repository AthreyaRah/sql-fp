import React, {useCallback, useMemo, useRef, useState, type JSX} from 'react';
import BrowserOnly from '@docusaurus/BrowserOnly';
import clsx from 'clsx';
import styles from './styles.module.css';
import {createDb, type QueryResult, type RunnerDb} from './pglite';

export interface SqlRunnerProps {
  /** SQL run once before the first query — CREATE TABLE / INSERT the dummy data. */
  setup?: string;
  /** Initial editor contents. */
  children?: string;
  query?: string;
  /** Rows to show before truncating the output grid. */
  maxRows?: number;
  /** Short label shown in the toolbar. */
  title?: string;
}

function fmtCell(v: unknown): JSX.Element | string {
  if (v === null || v === undefined) return <span className={styles.null}>NULL</span>;
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'object') return JSON.stringify(v);
  return String(v);
}

function ResultView({
  result,
  maxRows,
}: {
  result: QueryResult;
  maxRows: number;
}): JSX.Element {
  const cols =
    result.fields?.length > 0
      ? result.fields.map((f) => f.name)
      : Object.keys(result.rows[0] ?? {});

  if (cols.length === 0) {
    return (
      <p className={styles.ok}>
        OK{typeof result.affectedRows === 'number' ? ` — ${result.affectedRows} row(s) affected` : ''}
      </p>
    );
  }

  const shown = result.rows.slice(0, maxRows);
  return (
    <>
      <table className={styles.grid}>
        <thead>
          <tr>
            {cols.map((c) => (
              <th key={c}>{c}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {shown.map((row, i) => (
            <tr key={i}>
              {cols.map((c) => (
                <td key={c}>{fmtCell(row[c])}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
      <p className={styles.rowcount}>
        {result.rows.length} row{result.rows.length === 1 ? '' : 's'}
        {result.rows.length > maxRows ? ` (showing first ${maxRows})` : ''}
      </p>
    </>
  );
}

function Runner({setup, query, initial, maxRows, title}: {
  setup?: string;
  query: string;
  initial: string;
  maxRows: number;
  title?: string;
}): JSX.Element {
  const [sql, setSql] = useState(initial);
  const [busy, setBusy] = useState(false);
  const [booted, setBooted] = useState(false);
  const [result, setResult] = useState<QueryResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const dbRef = useRef<RunnerDb | null>(null);

  const lines = Math.min(Math.max(sql.split('\n').length + 1, 3), 18);

  const ensureDb = useCallback(async (): Promise<RunnerDb> => {
    if (!dbRef.current) {
      dbRef.current = await createDb(setup);
      setBooted(true);
    }
    return dbRef.current;
  }, [setup]);

  const run = useCallback(async () => {
    setBusy(true);
    setError(null);
    try {
      const db = await ensureDb();
      setResult(await db.query(sql));
    } catch (e) {
      setResult(null);
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }, [ensureDb, sql]);

  const reset = useCallback(async () => {
    setSql(initial);
    setError(null);
    setResult(null);
    // rebuild a clean database so edits to earlier statements don't linger
    dbRef.current = null;
    setBooted(false);
  }, [initial]);

  const onKeyDown = (e: React.KeyboardEvent) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      void run();
    }
  };

  return (
    <div className={styles.runner}>
      <div className={styles.bar}>
        <span className={styles.badge}>{title ?? 'SQL'} · PostgreSQL in your browser</span>
        <span className={styles.spacer} />
        <button className={styles.btn} onClick={reset} disabled={busy}>
          Reset
        </button>
        <button className={clsx(styles.btn, styles.run)} onClick={run} disabled={busy}>
          {busy ? 'Running…' : booted ? 'Run ▶' : 'Run ▶'}
        </button>
      </div>
      <textarea
        className={styles.editor}
        value={sql}
        rows={lines}
        spellCheck={false}
        onChange={(e) => setSql(e.target.value)}
        onKeyDown={onKeyDown}
        aria-label="SQL editor"
      />
      <div className={styles.output}>
        {!booted && !busy && !error && !result && (
          <span className={styles.hint}>
            Press <kbd>Run</kbd> (or ⌘/Ctrl+Enter). First run downloads a ~3&nbsp;MB
            Postgres engine, then it&apos;s instant.
          </span>
        )}
        {busy && <span className={styles.hint}>Running…</span>}
        {error && <pre className={styles.error}>ERROR:  {error}</pre>}
        {result && !error && <ResultView result={result} maxRows={maxRows} />}
      </div>
    </div>
  );
}

/**
 * SqlRunner — an editable SQL cell that runs against a real PostgreSQL engine
 * (PGlite / WASM) in the reader's browser. Each runner gets its own throwaway
 * database seeded from `setup`.
 *
 * <SqlRunner setup={SCHEMA}>{`SELECT * FROM orders;`}</SqlRunner>
 */
export default function SqlRunner(props: SqlRunnerProps): JSX.Element {
  const initial = (props.query ?? props.children ?? '').replace(/^\n+|\s+$/g, '');
  const maxRows = props.maxRows ?? 50;
  return (
    <BrowserOnly
      fallback={
        <div className={styles.runner}>
          <div className={styles.bar}>
            <span className={styles.badge}>SQL</span>
          </div>
          <pre className={styles.editor} style={{whiteSpace: 'pre-wrap'}}>
            {initial}
          </pre>
        </div>
      }
    >
      {() => (
        <Runner
          setup={props.setup}
          query={initial}
          initial={initial}
          maxRows={maxRows}
          title={props.title}
        />
      )}
    </BrowserOnly>
  );
}
