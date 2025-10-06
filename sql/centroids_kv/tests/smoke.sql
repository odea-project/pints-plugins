-- tests/smoke.sql for plugin centroids_kv
-- This test assumes the plugin schema is installed.
-- It checks for schema existence and parses materialize/export scripts.

-- List existing tables and views (should include cwf_steps, cprop_defs, centroids_core, centroid_kv)
PRAGMA show_tables;

-- Verify that mandatory tables exist
SELECT 'cwf_steps'       AS table_name WHERE EXISTS (SELECT * FROM duckdb_tables() WHERE table_name='cwf_steps')
UNION ALL
SELECT 'cprop_defs'      WHERE EXISTS (SELECT * FROM duckdb_tables() WHERE table_name='cprop_defs')
UNION ALL
SELECT 'centroid_kv'     WHERE EXISTS (SELECT * FROM duckdb_tables() WHERE table_name='centroid_kv');

-- Run materialize (no-op if staging table is empty)
.read ../materialize.sql

-- Run export query (should parse and return 0 rows if table is empty)
.read ../export.sql;

-- Optional: sanity query (count tables)
SELECT COUNT(*) AS n_tables FROM duckdb_tables() WHERE table_name LIKE 'centroid%';
