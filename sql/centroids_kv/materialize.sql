-- sql/centroids_kv/materialize.sql
-- expected: staging_centroids_kv(sample_id, run_id, step_id, centroid_id, prop_key, value DOUBLE)

-- 1) Register Properties
INSERT INTO cprop_defs(prop_key)
SELECT DISTINCT prop_key FROM staging_centroids_kv
ON CONFLICT (prop_key) DO NOTHING;

-- 2) Fill Core (mz/rt, if available)
INSERT OR REPLACE INTO centroids_core (sample_id, run_id, step_id, centroid_id, mz, rt)
SELECT
  s.sample_id, s.run_id, s.step_id, s.centroid_id,
  MAX(CASE WHEN s.prop_key='mz' THEN s.value END) AS mz,
  MAX(CASE WHEN s.prop_key='rt' THEN s.value END) AS rt
FROM staging_centroids_kv s
GROUP BY 1,2,3,4;

-- 3) Write KV values
INSERT OR REPLACE INTO centroid_kv (sample_id, run_id, step_id, centroid_id, prop_key, value)
SELECT sample_id, run_id, step_id, centroid_id, prop_key, value
FROM staging_centroids_kv;
