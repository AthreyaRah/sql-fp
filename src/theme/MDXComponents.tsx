import MDXComponents from '@theme-original/MDXComponents';
import QueryTrace from '@site/src/components/QueryTrace';
import SqlRunner from '@site/src/components/SqlRunner';
import RunThis from '@site/src/components/RunThis';

// Registered globally so topic pages can use these without an import line.
export default {
  ...MDXComponents,
  QueryTrace,
  SqlRunner,
  RunThis,
};
