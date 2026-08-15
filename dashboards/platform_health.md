# Dashboard: Platform Health

**Audience**: `mobility_data_engineers`
**Source**: `bronze`, `quarantine`, and `monitoring` schemas (intentionally, not `gold` — see rationale below)

## Purpose

Pipeline observability: how much data was processed, how much was rejected, and how the pipeline itself is performing. This is an engineering/operations dashboard, not a business analytics dashboard.

## Visuals

| Visual | Metric | Dataset |
|---|---|---|
| Counter | Total Events Processed | `events_processed` |
| Counter | Total Invalid Events | `data_quality_score` |
| Counter | Duplicates Removed | `duplicates_removed` |
| Counter | Late Events Detected | `late_events` |
| Counter | Avg Processing Latency (sec) | `processing_latency` |
| Counter | Data Quality Score % | `data_quality_score` |
| Bar chart | Records failed per rule | `failed_quality_rules` |
| Table | Pipeline task run history (task, duration, status, start time) | `pipeline_durations` |

## Why This Dashboard Doesn't Read From Gold

Gold tables contain only clean, validated data by design — that is the entire point of the medallion architecture. Metrics like "duplicates removed" or "invalid events" describe properties of the raw ingestion and validation process, and simply don't exist once data has reached Gold. Querying `bronze`, `quarantine`, and `monitoring` directly for this dashboard is the architecturally correct choice, not an inconsistency with the other two dashboards (which correctly do read from Gold, since they are business-facing).

## Counter Configuration Note

Early versions of these counters displayed `1` for every metric instead of the real measured value, because the visual's aggregation was set to "Count of rows" (each underlying query returns exactly one row) rather than the actual field value. This was corrected by setting each counter's aggregation to `Sum`/`Max` on the specific metric column.