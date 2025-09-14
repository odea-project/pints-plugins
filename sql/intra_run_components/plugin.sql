-- intra_run_components/plugin.sql
-- Minimal, idempotent schema for mapping features -> intra_run_component_id (per run)

CREATE TABLE IF NOT EXISTS intra_run_component_map (
  sample_id               TEXT NOT NULL REFERENCES samples(sample_id),
  run_id                  TEXT NOT NULL REFERENCES runs(run_id),
  feature_id              TEXT NOT NULL REFERENCES features(feature_id),
  intra_run_component_id  TEXT NOT NULL,             -- the grouping key (within a run)
  PRIMARY KEY (run_id, feature_id)                   -- one component per feature per run
);

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_irc_by_component ON intra_run_component_map(run_id, intra_run_component_id);
CREATE INDEX IF NOT EXISTS idx_irc_by_sample    ON intra_run_component_map(sample_id);

-- Convenience view (tidy export)
CREATE OR REPLACE VIEW v_intra_run_components AS
SELECT sample_id, run_id, feature_id, intra_run_component_id
FROM intra_run_component_map
ORDER BY sample_id, run_id, intra_run_component_id, feature_id;
