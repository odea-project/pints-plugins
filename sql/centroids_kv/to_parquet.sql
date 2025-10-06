-- sql/centroids_kv/to_parquet.sql
COPY centroid_kv
TO '/data/centroid_kv/'
(FORMAT PARQUET, PARTITION_BY (run_id, step_id, prop_key), COMPRESSION ZSTD);

COPY centroids_core
TO '/data/centroids_core/'
(FORMAT PARQUET, PARTITION_BY (run_id, step_id), COMPRESSION ZSTD);
