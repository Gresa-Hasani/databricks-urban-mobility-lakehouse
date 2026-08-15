# Data Model

All tables live under the `urban_mobility` catalog in Unity Catalog, organized into five schemas.

## Bronze (`urban_mobility.bronze`)

Raw, close to source, no business transformation. Every table includes `_source_file`, `_ingested_at` (and `_rescued_data` for Auto Loader-ingested tables, capturing anything that doesn't match the inferred schema).

| Table | Description | Row count (measured) |
|---|---|---|
| `trip_events` | Raw lifecycle events from Auto Loader | 8,751,802 |
| `drivers` | Raw synthetic driver records | 10,000 |
| `vehicles` | Raw synthetic vehicle records | 10,000 |
| `zones` | Real NYC TLC zone lookup | 265 |
| `trip_events_staging` | Intermediate table (pre-batching), not part of the official schema | 8,708,425 |

## Silver (`urban_mobility.silver`)

Typed, standardized, deduplicated, enriched.

| Table | Description | Row count (measured) |
|---|---|---|
| `trip_events_clean` | Validated events, duplicates removed via watermarked `dropDuplicates` | 8,342,336 |
| `trips_current` | One row per trip, current lifecycle state (built via Delta MERGE) | 1,736,194 |
| `trips_enriched` | `trips_current` joined with driver/vehicle/zone reference data, plus derived features | 1,736,194 |
| `drivers` | Cleaned, deduplicated driver reference data | 10,000 |
| `vehicles` | Cleaned, deduplicated vehicle reference data | 10,000 |
| `zones` | Cleaned zone reference data | 265 |

`trips_enriched` derived columns: `trip_duration_minutes`, `average_speed_kmh`, `revenue_per_km`, `pickup_hour`, `pickup_day_of_week`, `is_weekend`, `is_peak_hour` (peak = 7–9 and 16–19).

## Quarantine (`urban_mobility.quarantine`)

| Table | Description |
|---|---|
| `invalid_trip_events` | Records that failed one or more data quality rules. Schema: `event_id`, `trip_id`, `failed_rule`, `failure_reason`, `raw_payload` (full original row as JSON), `source_file`, `detected_at`. |

## Gold (`urban_mobility.gold`)

Business-oriented, analytics-ready data products.

| Table | Grain | Key columns |
|---|---|---|
| `zone_demand_5min` | 5-minute window × pickup zone | `trip_requests`, `completed_trips`, `cancelled_trips`, `active_drivers`, `demand_supply_ratio`, `demand_level` |
| `hourly_revenue` | Hour | `trip_count`, `gross_revenue`, `tip_revenue`, `toll_revenue`, `avg_fare`, `avg_trip_value`, `revenue_per_km` |
| `driver_performance` | Driver | `total_trips`, `completed_trips`, `cancelled_trips`, `total_revenue`, `avg_trip_revenue`, `avg_rating`, `total_distance_km`, `completion_rate`, `cancellation_rate`, `revenue_per_hour` — no driver PII |
| `route_performance` | Pickup zone × dropoff zone | `trip_count`, `avg_duration_minutes`, `avg_distance_km`, `avg_fare`, `total_revenue`, `avg_speed_kmh`, `peak_hour` |
| `daily_mobility_kpis` | Day | `trip_requests`, `completed_trips`, `cancelled_trips`, `completion_rate`, `total_revenue`, `avg_fare`, `avg_trip_distance_km`, `avg_duration_minutes`, `active_drivers`, `peak_demand_hour` |
| `trip_anomalies` | Trip (flagged only) | `anomaly_type` (`IMPOSSIBLE_SPEED`, `EXTREME_FARE`, `EXTREME_DURATION`, `DISTANCE_FARE_MISMATCH`), plus the underlying metrics that triggered the flag |

## Monitoring (`urban_mobility.monitoring`)

| Table | Description |
|---|---|
| `data_quality_results` | Per-rule, per-run metrics: `run_id`, `table_name`, `rule_name`, `records_checked`, `records_failed`, `failure_percentage`, `execution_timestamp` |
| `pipeline_runs` | Per-task execution log: `run_id`, `pipeline_name`, `task_name`, `started_at`, `completed_at`, `records_read`, `records_written`, `records_rejected`, `duration_seconds`, `status`, `error_message` |
| `streaming_metrics` | Per-batch streaming query metrics: `input_rows_per_second`, `processed_rows_per_second`, `batch_duration_ms`, `num_input_rows` |

## Referential Notes

- `pickup_zone_id` / `dropoff_zone_id` reference `silver.zones.zone_id` (real NYC TLC zone IDs, 265 total)
- `driver_id` references `silver.drivers.driver_id`; `vehicle_id` references `silver.vehicles.vehicle_id`
- Driver/vehicle are assigned 1-to-1 at generation time (see `docs/data_quality.md` for the birthday-paradox issue encountered and fixed when this was originally a many-to-one random assignment)