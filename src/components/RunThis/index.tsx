import React, {type JSX} from 'react';
import Admonition from '@theme/Admonition';

const REPO = 'https://github.com/AthreyaRah/sql-fp/blob/main';

export interface RunThisProps {
  /** Repo-relative path, e.g. "sql/foundations/11_group_by_and_aggregation/topic.sql". */
  file: string;
}

/**
 * A pointer to the topic's full self-contained script on GitHub — for readers
 * who'd rather run it in a local `psql` / pgAdmin than the in-page runner.
 * The script is what CI executes against a real PostgreSQL 16.
 */
export default function RunThis({file}: RunThisProps): JSX.Element {
  return (
    <Admonition type="info" title="Prefer a real database?">
      <p>
        Everything on this page also lives in one self-contained script —
        schema, seed rows, and every query — that runs on a stock PostgreSQL:
      </p>
      <p>
        <a href={`${REPO}/${file}`} target="_blank" rel="noreferrer">
          <code>{file}</code>
        </a>
      </p>
      <p>
        <code>psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f {file}</code>. See{' '}
        <a href="/sql-fp/appendix/run-locally">Run locally</a> for a five-minute
        Postgres setup.
      </p>
    </Admonition>
  );
}
