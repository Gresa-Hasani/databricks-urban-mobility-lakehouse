# Streaming Architecture

## Why Auto Loader

Trip event batches arrive as discrete JSON files in a landing volume. Auto Loader (`cloudFiles`) was chosen over a plain batch `spark.read` loop because it provides:

- **Incremental file discovery**: only newly-arrived files are processed on each run, tracked via checkpoint — critical for a pipeline that will receive new batches over time.
- **Schema inference and evolution**: new fields (e.g., a hypothetical `rating_given_by_passenger` added later) are captured automatically in `_rescued_data` rather than breaking the pipeline.
- **Restart safety**: if a run is interrupted, the next run resumes from the last successfully processed file rather than reprocessing everything or losing state.

## Trigger Mode: `availableNow` over Continuous

The pipeline uses `trigger(availableNow=True)` rather than a continuously-running stream. This was a deliberate engineering trade-off for this project:

- A 24/7 continuously running cluster is not practical or necessary for a batch-replay-style historical simulation running on Databricks Free Edition serverless compute.
- `availableNow` still uses the full Structured Streaming engine — checkpointing, watermarking, exactly-once semantics — it simply processes everything currently available and then stops, rather than polling indefinitely.
- In production, the same code would run under Lakeflow Jobs on a schedule (e.g., every 5 minutes), which is functionally equivalent to a continuous stream at that granularity. This is exactly how it is deployed here: `ingest_trip_events` is one task in the 15-task Lakeflow Jobs DAG.

## Watermarking and Late Events

`clean_trip_events` applies `withWatermark("event_timestamp", "2 hours")` before deduplication. This bounds how long Spark retains state for `dropDuplicates`, which is necessary for any long-running or repeatedly-triggered streaming job to avoid unbounded state growth.

**Honest caveat, documented rather than hidden**: because this pipeline replays historical data via `trigger(availableNow=True)`, most of the ~8.7M events arrive within a single micro-batch window. In a truly continuous production stream, the 2-hour watermark would cause events arriving more than 2 hours after the current watermark position to be dropped from deduplication state (though not necessarily from the output — Structured Streaming's watermark affects state cleanup, not filtering, unless combined with `outputMode` restrictions). In this replay scenario, the watermark's practical effect is smaller than it would be in continuous production streaming, since the state window rarely advances far enough to evict genuinely late data mid-run. This is a known and documented difference between batch-replay demonstration and continuous production streaming — not a bug.

Late events were still deliberately injected (0.3% of events, `event_timestamp` shifted 6 hours into the past) to demonstrate that the mechanism is wired correctly; their presence is measurable via the `late_events` query in the Platform Health dashboard, which compares `event_timestamp` against `_ingested_at`.

## Deduplication

Exact-duplicate events (same `event_id`, injected at 0.5%) are removed via `dropDuplicates(["event_id"])` combined with the watermark above. This was verified empirically: after bad-data injection, `bronze.trip_events` contained 8,751,802 rows; after deduplication and validation, `silver.trip_events_clean` + `quarantine.invalid_trip_events` summed to exactly 8,708,425 — the original pre-duplication event count — confirming that duplicates (43,377 rows) were removed correctly and nothing else was lost or double-counted.

## Checkpointing

Each streaming task has its own checkpoint location under `/Volumes/urban_mobility/bronze/checkpoints/`:
- `trip_events/` for `ingest_trip_events`
- `clean_trip_events/` for `clean_trip_events`

Checkpoints must persist across production runs to preserve incremental behavior. During development, checkpoints were deliberately cleared multiple times to force full reprocessing after upstream fixes (e.g., after correcting the vehicle-to-driver assignment logic) — this manual reset behavior is intentionally excluded from the Lakeflow Jobs task notebooks, since running it automatically on every scheduled execution would defeat incremental processing entirely.

## Serverless Compute Limitations Encountered

Several standard PySpark patterns are not available on Databricks Serverless compute (Spark Connect), discovered during development:

- `.cache()` / `.persist()` — not supported (`NOT_SUPPORTED_WITH_SERVERLESS`). Optimization instead focused on reducing the *number* of Spark actions (e.g., replacing nine separate `.filter().count()` calls with a single `.agg()` pass) rather than caching intermediate results.
- `.rdd` — not implemented on Spark Connect; `DataFrame.isEmpty()` was used instead of `.rdd.isEmpty()` for empty-batch checks.
- `spark.conf.set("spark.sql.autoBroadcastJoinThreshold", ...)` — restricted on serverless; benchmarking instead compared default (AQE-managed) join behavior against an explicit `F.broadcast()` hint, which is a query-level hint rather than a session-level config change.

These are documented here rather than worked around silently, since they materially affected the optimization approach taken in `docs/performance.md`.