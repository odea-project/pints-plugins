# Centroids (EAV, DOUBLE-only) (`centroids_kv`)

This plugin defines a **dynamic Entity–Attribute–Value (EAV)** schema for managing centroid-level properties from any workflow step. All property values are stored as `DOUBLE`, allowing flexible extension without altering the database schema.

---

## 📁 Files

| File | Purpose |
|------|----------|
| `manifest.yaml` | Declarative metadata: staging schema + actions |
| `plugin.sql` | Defines all permanent tables (`cwf_steps`, `cprop_defs`, `centroids_core`, `centroid_kv`) |
| `materialize.sql` | Loads data from the staging table into the permanent tables |
| `export.sql` | Default export (long EAV format) |
| `tests/smoke.sql` | Minimal smoke test for schema existence |

---

## 🧱 Schema overview

| Table | Purpose |
|--------|----------|
| `cwf_steps` | Registry of workflow steps (`step_id`, label, description) |
| `cprop_defs` | Registry of centroid property keys (metadata for each `prop_key`) |
| `centroids_core` | Optional fast-access table for frequently used base fields (`mz`, `rt`) |
| `centroid_kv` | Main EAV table containing all `(run_id, step_id, centroid_id, prop_key, value)` entries |

All values are numeric (`DOUBLE`). New properties and workflow steps are automatically registered.

---

## 🧩 Staging schema

The plugin defines a staging table `staging_centroids_kv` with:

```
sample_id:TEXT
run_id:TEXT
step_id:TEXT
centroid_id:BIGINT
prop_key:TEXT
value:DOUBLE
```

Each row represents **one centroid property value**.

Example CSV:

```csv
sample_id,run_id,step_id,centroid_id,prop_key,value
S001,R001,qcentroids,17,mz,123.4567
S001,R001,qcentroids,17,intensity,120000
S001,R001,qcentroids,17,sigma_mz,0.00004
```

---

## ⚙️ Typical workflow

```bash
# 1. Install schema into DuckDB
pints plugin install --db pints.duckdb --name centroids_kv

# 2. Create staging table and load raw data
pints plugin staging-create --db pints.duckdb --name centroids_kv
pints plugin load-csv       --db pints.duckdb --name centroids_kv --csv example.csv

# 3. Materialize: move data from staging into permanent tables
pints plugin action         --db pints.duckdb --name centroids_kv --action materialize

# 4. Export results as CSV
pints plugin export         --db pints.duckdb --name centroids_kv --out centroids_kv.csv
```

---

## 📦 Optional: Parquet export

For large datasets, use the additional `to_parquet.sql` action (if present):

```bash
pints plugin action --db pints.duckdb --name centroids_kv --action to_parquet
```

This writes partitioned Parquet files grouped by `run_id`, `step_id`, and `prop_key` for efficient analytics in DuckDB or Python.

---

## 🔍 Notes

- The design follows the **EAV pattern** (Entity = centroid, Attribute = property key, Value = numeric value).
- All numeric data are stored as `DOUBLE`.
- You can query wide views on demand using `PIVOT` or precompute them in your tools.
- Compatible with all PINTS CLI commands and data pipelines.