# Data Quality

## Framework Design

The data quality framework is split into two files to separate **what** is checked from **how** it is executed:

- `src/quality/rules.py` — declarative list of rule definitions (name, Spark SQL condition via `F.expr`, description)
- `src/quality/validator.py` — reusable `run_validation()` function that applies any rule list to any DataFrame, splits it into valid/invalid, and produces per-rule metrics

This separation means new rules can be added without touching execution logic, and the same validator can be reused for any table, not just `trip_events`.

## Rules

| Rule | Checks |
|---|---|
| `trip_id_not_null` | `trip_id` is not null |
| `event_id_not_null` | `event_id` is not null |
| `driver_required_for_started_trip` | `driver_id` is not null once a driver has been assigned (`DRIVER_ASSIGNED`, `TRIP_STARTED`, `TRIP_COMPLETED`, `PAYMENT_COMPLETED`, `TRIP_CANCELLED`) |
| `positive_distance` | `distance_km` > 0 when present |
| `non_negative_fare` | `fare_amount` >= 0 when present |
| `valid_pickup_zone` | `pickup_zone_id` is not the unknown-zone sentinel (9999) |
| `valid_dropoff_zone` | `dropoff_zone_id` is not the unknown-zone sentinel |
| `dropoff_after_pickup` | `dropoff_datetime` >= `pickup_datetime` |
| `surge_multiplier_valid` | `surge_multiplier` between 1.0 and 5.0 |

## A Rule Gap Found During Development

`driver_required_for_started_trip` initially excluded `TRIP_CANCELLED` from its event-type check. Since cancellation only occurs after `DRIVER_ASSIGNED` in this event model, a cancelled trip's driver ID should logically never be null — but the rule as first written allowed it to pass validation anyway. This let 276 cancelled trips with a null `driver_id` (from the `missing_id` injection landing specifically on the cancellation event) reach `gold.driver_performance` as a phantom "driver". The rule was corrected to include `TRIP_CANCELLED`, and the pipeline was rerun — quarantined records for this rule increased from ~13,800 to ~14,000 (closely matching the expected +0.2% × ~144K cancelled trips), confirming the fix worked. This is documented as a real example of iterative rule refinement, not hidden as if the rule were correct from the start.

## Why Invalid Records Are Quarantined, Not Dropped

`quarantine.invalid_trip_events` stores every record that fails validation, along with which rule(s) it failed, a human-readable failure reason, and the full original row as JSON (`raw_payload`). Silently dropping invalid records would make it impossible to audit data quality over time, debug upstream issues, or recover records if a rule turns out to be too strict. Quarantining is the standard pattern for a governed lakehouse: bad data is isolated, not destroyed.

## Measured Results

From the full pipeline run over ~8.75M events (post duplicate-injection):

- `silver.trip_events_clean`: 8,342,336 records
- `quarantine.invalid_trip_events`: ~366,000 records (~4.2% of events)
- Sum matches the pre-duplication event count (8,708,425) exactly, confirming deduplication ran before validation with no records lost or double-counted

The ~4.2% quarantine rate is higher than the ~0.75% of bad data intentionally injected. The difference comes from **natural data quality issues already present in the real NYC TLC source data** (e.g., zero-distance trips, occasional fare anomalies in the original dataset) layered on top of the intentionally injected problems — not a flaw in the framework. This is called out explicitly because it demonstrates the framework catching genuine real-world data issues, not just the synthetic ones it was designed to catch.

## Deduplication

Deduplication is handled at the Silver layer via `dropDuplicates(["event_id"])` combined with event-time watermarking (see `docs/streaming.md`), applied before validation so that exact duplicates are removed once, not validated (and potentially quarantined) twice.