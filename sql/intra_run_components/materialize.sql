-- intra_run_components/materialize.sql
-- Expects a TEMP table named tmp_intra_run_components(run_id TEXT, feature_id TEXT, intra_run_component_id TEXT)
-- Populated by your tool/script before running this SQL.

-- Ensure the temp input exists (no-op if already there)
CREATE TEMP TABLE IF NOT EXISTS tmp_intra_run_components (
  run_id TEXT,
  feature_id TEXT,
  intra_run_component_id TEXT
);

-- Upsert into the mapping table, deriving sample_id from runs
INSERT OR REPLACE INTO intra_run_component_map (sample_id, run_id, feature_id, intra_run_component_id)
SELECT
  r.sample_id,
  s.run_id,
  s.feature_id,
  s.intra_run_component_id
FROM staging_intra_run_components s
JOIN runs r ON r.run_id = s.run_id;
