#!/usr/bin/env python3
"""
Scaffold a new PINTS plugin folder with manifest + SQL templates.

Usage:
  python tools/create_new_plugin.py --name intra_run_components
  python tools/create_new_plugin.py --name dqs --title "Data Quality Scores" --staging-cols run_id:TEXT feature_id:TEXT score:DOUBLE

It will create:
  sql/<name>/
    manifest.yaml
    plugin.sql
    materialize.sql
    export.sql
    README.md
    tests/smoke.sql
"""

from __future__ import annotations
import argparse
import re
from datetime import datetime
from pathlib import Path
from textwrap import dedent

DEFAULT_STAGING = ["run_id:TEXT", "feature_id:TEXT", "intra_run_component_id:TEXT"]

def parse_cols(items: list[str]) -> list[tuple[str,str]]:
    cols = []
    for it in items:
        if ":" not in it:
            raise SystemExit(f"Invalid --staging-cols entry (use name:TYPE): {it}")
        name, typ = it.split(":", 1)
        name = name.strip()
        typ = typ.strip().upper()
        if not name or not typ:
            raise SystemExit(f"Invalid column spec: {it}")
        cols.append((name, typ))
    return cols

def snake_case_ok(name: str) -> bool:
    return re.fullmatch(r"[a-z][a-z0-9_]*", name) is not None

def main():
    ap = argparse.ArgumentParser(description="Create a new PINTS plugin skeleton.")
    ap.add_argument("--name", required=True, help="Plugin folder/name (snake_case, e.g. intra_run_components)")
    ap.add_argument("--title", default=None, help="Human title/description")
    ap.add_argument("--root", default="sql", help="Target root for plugins (default: sql)")
    ap.add_argument("--version", default="0.1.0", help="Initial plugin version")
    ap.add_argument("--staging-cols", nargs="+", default=DEFAULT_STAGING,
                    help="Staging column list like 'run_id:TEXT feature_id:TEXT foo:DOUBLE' (default geared to intra_run_components)")
    args = ap.parse_args()

    name = args.name.strip()
    if not snake_case_ok(name):
        raise SystemExit("Plugin name must be snake_case: [a-z][a-z0-9_]*")

    cols = parse_cols(args.staging_cols)
    title = args.title or name.replace("_", " ").title()
    root = Path(args.root)
    plugdir = root / name
    (plugdir / "tests").mkdir(parents=True, exist_ok=True)

    # Derive staging table name and a permanent table name suggestion
    staging_table = f"staging_{name}"
    # For common map-style plugins, we propose a “map” table; customizable by editing later:
    map_table = f"{name}_map"
    view_name = f"v_{name}_features"  # sensible default; adjust as needed

    # manifest.yaml
    manifest = dedent(f"""\
    name: {name}
    version: {args.version}
    license: MIT
    compat:
      pints-core-sql: ">=1.0,<2.0"

    schema: plugin.sql

    staging:
      table: {staging_table}
      columns:
    """)
    for n, t in cols:
        manifest += f"        - {{ name: {n}, type: {t} }}\n"
    manifest += dedent(f"""
      load:
        header: true
        delimiter: ","
        autodetect: true

    actions:
      - name: materialize
        file: materialize.sql
      - name: export
        file: export.sql
        kind: select
    """)

    # plugin.sql (permanent tables + view)
    # We try to detect typical core FKs if the common columns exist
    has_run = any(c[0] == "run_id" for c in cols)
    has_feat = any(c[0] == "feature_id" for c in cols)
    has_component = any(c[0] in ("component_id", "intra_run_component_id") for c in cols)
    # choose a "component id" column if present, else use first non-run/feature col
    comp_col = next((c[0] for c in cols if c[0] in ("intra_run_component_id","component_id")), None)
    if comp_col is None:
        comp_col = next((c[0] for c in cols if c[0] not in ("run_id","feature_id")), "group_id")
    
    plugin_sql = f"""\
-- {name}/plugin.sql
-- Plugin schema for: {title}
-- Generated: {datetime.now().isoformat(timespec='seconds')}Z

-- Permanent mapping table (edit to your needs)
CREATE TABLE IF NOT EXISTS {map_table} (
  sample_id  TEXT,
  {"run_id TEXT NOT NULL REFERENCES runs(run_id)," if has_run else ""}
  {"feature_id TEXT NOT NULL REFERENCES features(feature_id)," if has_feat else ""}
  {comp_col}  TEXT NOT NULL,
  {"PRIMARY KEY (run_id, feature_id)" if has_run and has_feat else "PRIMARY KEY (" + comp_col + ")"}
);

-- Helpful indexes
{"CREATE INDEX IF NOT EXISTS idx_" + name + "_by_component ON " + map_table + "(" + comp_col + ");" if comp_col else ""}
{"CREATE INDEX IF NOT EXISTS idx_" + name + "_by_run ON " + map_table + "(run_id);" if has_run else ""}

-- Convenience view (join to features if both sides exist)
{"CREATE OR REPLACE VIEW " + view_name + " AS\nSELECT m.sample_id, m.run_id, m." + comp_col + " AS component_id, f.feature_id, f.mz, f.rt, f.area\nFROM " + map_table + " m\nJOIN features f ON f.feature_id = m.feature_id" + (" AND f.run_id = m.run_id" if has_run else "") + ";\n" if has_feat else "-- (No features join generated; add your own view if needed)\n"}
"""

    # materialize.sql (pull from staging, derive sample_id from runs if possible)
    if has_run:
        mat_sql = f"""\
-- {name}/materialize.sql
-- Move rows from {staging_table} into {map_table}. Derive sample_id from runs (if available).

INSERT OR REPLACE INTO {map_table} (sample_id, {"run_id, " if has_run else ""}{"feature_id, " if has_feat else ""}{comp_col})
SELECT
  r.sample_id,
  {"s.run_id," if has_run else ""}
  {"s.feature_id," if has_feat else ""}
  s.{comp_col}
FROM {staging_table} s
JOIN runs r ON r.run_id = s.run_id
{"JOIN features f ON f.feature_id = s.feature_id AND f.run_id = s.run_id" if has_feat else ""};
"""
    else:
        mat_sql = f"""\
-- {name}/materialize.sql
-- Move rows from {staging_table} into {map_table} (no run_id in staging; edit as needed).

INSERT OR REPLACE INTO {map_table} ({("feature_id, " if has_feat else "")}{comp_col})
SELECT
  {"s.feature_id," if has_feat else ""}
  s.{comp_col}
FROM {staging_table} s;
"""

    # export.sql
    export_sql = f"""\
-- {name}/export.sql
{"SELECT * FROM " + view_name + " ORDER BY " + ("run_id, component_id" if has_run else comp_col) + ", feature_id;" if has_feat else "SELECT * FROM " + map_table + " ORDER BY " + (("run_id, " if has_run else "") + comp_col) + ";"}
"""

    # README.md for the plugin
    readme = f"""\
# {title} ({name})

This plugin was scaffolded by `tools/new_plugin.py`.

## Files
- `manifest.yaml` : declarative metadata (staging schema, actions)
- `plugin.sql`    : permanent tables/views (idempotent)
- `materialize.sql` : move data from staging into permanent tables
- `export.sql`      : CSV-ready SELECT
- `tests/smoke.sql` : tiny smoke test

## Staging schema
The wrapper will create and load the staging table from `manifest.yaml`:

- table: `{staging_table}`
- columns: {", ".join([f"{n}:{t}" for n,t in cols])}

## Typical workflow
pints plugin install --db my.duckdb --name {name}
pints plugin load-csv --db my.duckdb --name {name} --csv example.csv
pints plugin action --db my.duckdb --name {name} --action materialize
pints plugin export --db my.duckdb --name {name} --out {name}.csv
"""

    # tests/smoke.sql — minimal, doesn’t depend on core
    smoke = f"""\
-- tests/smoke.sql for plugin {name}
-- This file assumes the plugin schema is installed.
-- It only checks basic existence and runs materialize as a no-op.

-- Show plugin tables/views (non-fatal if empty)
PRAGMA show_tables;

-- Run materialize (will no-op if staging is empty or core not present)
.read ../materialize.sql

-- Export query should parse
.read ../export.sql
"""

    # write files
    (plugdir / "manifest.yaml").write_text(manifest, encoding="utf-8")
    (plugdir / "plugin.sql").write_text(plugin_sql, encoding="utf-8")
    (plugdir / "materialize.sql").write_text(mat_sql, encoding="utf-8")
    (plugdir / "export.sql").write_text(export_sql, encoding="utf-8")
    (plugdir / "README.md").write_text(readme, encoding="utf-8")
    (plugdir / "tests" / "smoke.sql").write_text(smoke, encoding="utf-8")

    print(f"✅ Created plugin skeleton at: {plugdir.resolve()}")
    print("   Edit plugin.sql/materialize.sql/export.sql as needed.")
    print("   Then install via: pints plugin install --db my.duckdb --name", name)

if __name__ == "__main__":
    main()
