# Monitoring

## Tables

Three monitoring tables track different aspects of pipeline health, all under `urban_mobility.monitoring`:

- **`data_quality_results`** — per-rule, per-run outcome (`records_checked`, `records_failed`, `failure_percentage`), written every time `clean_trip_events` runs
- **`pipeline_runs`** — per-task execution log (`records_read`, `records_written`, `records_rejected`, `duration_seconds`, `status`, `error_message`), populated via a reusable `log_pipeline_run()` helper called at the end of key tasks (`ingest_trip_events`, `trip_anomalies`)
- **`streaming_metrics`** — per-batch Structured Streaming query metrics (`input_rows_per_second`, `processed_rows_per_second`, `batch_duration_ms`, `num_input_rows`), captured from `query.lastProgress` after each streaming run

## Design Decision: Real Metrics, Not Simulated

Rather than fabricating monitoring data, both `log_pipeline_run()` and `log_streaming_metrics()` are called from inside the actual production notebooks (`ingest_trip_events`, `trip_anomalies`) so that every row in these tables reflects an execution that genuinely happened. The first row in `pipeline_runs`, for example, was logged during the actual Gold-layer `trip_anomalies` run, with real `records_read`/`records_written` counts and a real measured duration.

## Platform Health Dashboard Queries

Since pipeline observability metrics (duplicates removed, invalid events, late events, processing latency) are properties of the raw ingestion and quality process, the Platform Health dashboard intentionally queries `bronze`, `quarantine`, and `monitoring` schemas directly — not `gold`. Gold tables contain only clean, validated data by design; concepts like "duplicates removed" don't exist there. See `docs/architecture.md` for the full rationale on why this dashboard breaks from the "dashboards should read from Gold" convention used by the other two dashboards.

## Orchestration Monitoring via Lakeflow Jobs

Beyond the custom monitoring tables, Lakeflow Jobs itself provides task-level run history, timing, and status for the full 15-task pipeline. This was used directly to observe and resolve a real failure during development:

- The `route_performance` task was misconfigured to use Serverless GPU compute (intended for ML workloads) instead of standard Serverless CPU compute, causing it to hang in a "Pending" state.
- The task was cancelled, its compute setting corrected, and the run was resumed using Databricks' **Repair Run** feature — which reruns only the failed/pending tasks, leaving already-succeeded tasks untouched.
- The job run history shows this concretely: `route_performance` completed in 43 seconds across **2 attempts** — a genuine, unstaged demonstration of retry/repair behavior, not a manufactured example.

A retry policy (2 retries, 5-minute interval, retry-on-timeout enabled) is also configured on `ingest_trip_events`, the task most exposed to Databricks Free Edition platform load variability observed repeatedly during development.