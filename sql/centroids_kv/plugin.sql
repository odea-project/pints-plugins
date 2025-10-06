-- PINTS Plugin: Centroids (Dynamic EAV, DOUBLE-only)
-- File: plugin.sql
-- Purpose: Defines minimal, reusable schema for centroid properties with
--          workflow & property registries. Designed for large-scale data
--          and optional Parquet partitioning.
-- Engine: DuckDB ≥ 0.10 (tested), but generic SQL kept simple.

-- Recommended runtime settings (set once per session, optional)
-- PRAGMA threads=ALL;                      -- use all CPU cores
-- PRAGMA memory_limit='8GB';               -- adjust to your machine
-- PRAGMA preserve_insertion_order=false;   -- let optimizer reorder

BEGIN TRANSACTION;

-- 1) Workflow step registry -------------------------------------------------
CREATE TABLE IF NOT EXISTS cwf_steps (
  step_id     TEXT PRIMARY KEY,         -- e.g. 'qcentroids', 'denoise'
  label       TEXT,
  description TEXT
);

-- 2) Property registry ------------------------------------------------------
CREATE TABLE IF NOT EXISTS cprop_defs (
  prop_key TEXT PRIMARY KEY,            -- e.g. 'mz','rt','intensity','sigma_mz', ...
  note     TEXT                         -- optional: unit, source, etc.
);

-- 3) Core identity (optional but useful for filters) ------------------------
-- Holds frequently-used base fields for quick predicates.
CREATE TABLE IF NOT EXISTS centroids_core (
  sample_id   TEXT NOT NULL,
  run_id      TEXT NOT NULL,
  step_id     TEXT NOT NULL,
  centroid_id BIGINT NOT NULL,          -- stable within (run_id, step_id)
  mz          DOUBLE,                   -- optional fast-access base fields
  rt          DOUBLE,
  PRIMARY KEY (run_id, step_id, centroid_id)
);

-- Helpful indexes for common filters on core (already covered by PK, but kept explicit)
CREATE INDEX IF NOT EXISTS idx_core_run_step ON centroids_core(run_id, step_id);
CREATE INDEX IF NOT EXISTS idx_core_mz ON centroids_core(mz);
CREATE INDEX IF NOT EXISTS idx_core_rt ON centroids_core(rt);

-- 4) Dynamic values (EAV, DOUBLE-only) -------------------------------------
-- Central store: one row per (run, step, centroid, property) with numeric value.
CREATE TABLE IF NOT EXISTS centroid_kv (
  sample_id   TEXT NOT NULL,
  run_id      TEXT NOT NULL,
  step_id     TEXT NOT NULL,
  centroid_id BIGINT NOT NULL,
  prop_key    TEXT NOT NULL,            -- references cprop_defs.prop_key (soft FK)
  value       DOUBLE NOT NULL,
  PRIMARY KEY (run_id, step_id, centroid_id, prop_key)
);

-- Helpful indexes to speed up selective scans and joins
CREATE INDEX IF NOT EXISTS idx_kv_run_step_prop ON centroid_kv(run_id, step_id, prop_key);
CREATE INDEX IF NOT EXISTS idx_kv_prop ON centroid_kv(prop_key);
CREATE INDEX IF NOT EXISTS idx_kv_centroid ON centroid_kv(centroid_id);

COMMIT;

-- ---------------------------------------------------------------------------
-- Optional: Standard convenience views (uncomment if you use Parquet layout)
-- ---------------------------------------------------------------------------
-- If you store big fact tables as partitioned Parquet datasets, expose them as
-- views so tools can query them like regular tables.

-- CREATE OR REPLACE VIEW centroid_kv_all AS
-- SELECT *
-- FROM read_parquet('/data/centroid_kv/run_id=*/step_id=*/prop_key=*/part-*.parquet');

-- CREATE OR REPLACE VIEW centroids_core_all AS
-- SELECT *
-- FROM read_parquet('/data/centroids_core/run_id=*/step_id=*/*.parquet');

-- Example views for common patterns -----------------------------------------
-- 1) List all properties present per (run, step)
-- CREATE OR REPLACE VIEW v_props_per_step AS
-- SELECT run_id, step_id, prop_key, COUNT(*) AS n
-- FROM centroid_kv
-- GROUP BY 1,2,3
-- ORDER BY run_id, step_id, prop_key;

-- 2) Late-pivot helper: narrow view limited to a run/step (fewer rows to pivot)
-- CREATE OR REPLACE VIEW v_kv_run_step AS
-- SELECT centroid_id, prop_key, value
-- FROM centroid_kv
-- WHERE run_id = 'R001' AND step_id = 'qcentroids';

-- You can then pivot on-demand:
-- SELECT * FROM v_kv_run_step
-- PIVOT(MAX(value) FOR prop_key IN ('mz','rt','intensity','sigma_mz'));

-- Seed examples (optional) ---------------------------------------------------
-- INSERT INTO cwf_steps(step_id, label, description) VALUES
--   ('qcentroids','qCentroids','Centroid detection step'),
--   ('denoise','Denoise','Noise filtering');

-- INSERT INTO cprop_defs(prop_key, note) VALUES
--   ('mz','mass-to-charge ratio'),
--   ('rt','retention time (s)'),
--   ('intensity','signal intensity'),
--   ('sigma_mz','uncertainty in m/z');

-- Example insert into core & kv
-- INSERT INTO centroids_core(sample_id, run_id, step_id, centroid_id, mz, rt)
-- VALUES ('S001','R001','qcentroids',1, 123.4567, 98.7);
-- INSERT INTO centroid_kv(sample_id, run_id, step_id, centroid_id, prop_key, value)
-- VALUES ('S001','R001','qcentroids',1,'intensity', 120345.0);

-- End of plugin.sql
