-- intra_run_components/materialize.sql
-- Action: materialize
-- Purpose:
--   Move assignments from staging_intra_run_components into the permanent mapping table.
--   If rows already exist (same run_id + feature_id), they are replaced.

INSERT OR REPLACE INTO intra_run_component_map (
    sample_id,
    run_id,
    feature_id,
    intra_run_component_id
)
SELECT
    r.sample_id,
    s.run_id,
    s.feature_id,
    s.intra_run_component_id
FROM staging_intra_run_components s
JOIN runs r ON r.run_id = s.run_id;
