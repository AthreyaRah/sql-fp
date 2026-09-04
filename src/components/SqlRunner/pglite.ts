/**
 * Lazy PGlite loader.
 *
 * PGlite is PostgreSQL compiled to WebAssembly — a real Postgres query engine
 * running entirely in the browser tab. No server, nothing to install, works on
 * a static site. We load it from a CDN on first use (with `webpackIgnore` so the
 * bundler leaves the dynamic import alone) and keep the module promise cached.
 */

const PGLITE_VERSION = '0.5.8';
const CDN = `https://cdn.jsdelivr.net/npm/@electric-sql/pglite@${PGLITE_VERSION}/dist/index.js`;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type PGliteModule = {new (): any; create?: unknown};

let modulePromise: Promise<{PGlite: PGliteModule}> | null = null;

export function loadPGliteModule(): Promise<{PGlite: PGliteModule}> {
  if (!modulePromise) {
    modulePromise = import(/* webpackIgnore: true */ CDN) as Promise<{
      PGlite: PGliteModule;
    }>;
  }
  return modulePromise;
}

export interface QueryResult {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  rows: Record<string, any>[];
  fields: {name: string}[];
  affectedRows?: number;
}

export interface RunnerDb {
  exec(sql: string): Promise<void>;
  query(sql: string): Promise<QueryResult>;
}

/** Create a fresh in-memory database and run the setup script against it. */
export async function createDb(setupSql?: string): Promise<RunnerDb> {
  const {PGlite} = await loadPGliteModule();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const pg: any = await new PGlite();
  if (setupSql && setupSql.trim()) {
    await pg.exec(setupSql);
  }
  return {
    exec: (sql: string) => pg.exec(sql),
    async query(sql: string): Promise<QueryResult> {
      // exec() runs multiple statements and returns the last result set.
      const results = await pg.exec(sql);
      const last = results[results.length - 1] ?? {rows: [], fields: []};
      return {
        rows: last.rows ?? [],
        fields: last.fields ?? [],
        affectedRows: last.affectedRows,
      };
    },
  };
}
