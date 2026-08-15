# Event Model

## Trip Lifecycle

Each trip is represented as a sequence of discrete events rather than a single row. This models how a real ride-hailing platform emits state changes over time.

```
TRIP_REQUESTED
      │
      ▼
DRIVER_ASSIGNED
      │
      ▼
TRIP_STARTED ──────────────► TRIP_CANCELLED (terminal)
      │
      ▼
TRIP_COMPLETED
      │
      ▼
PAYMENT_COMPLETED (terminal)
```

- **Completed trips** emit 5 events: `TRIP_REQUESTED → DRIVER_ASSIGNED → TRIP_STARTED → TRIP_COMPLETED → PAYMENT_COMPLETED`
- **Cancelled trips** emit 3 events: `TRIP_REQUESTED → DRIVER_ASSIGNED → TRIP_CANCELLED`
- In the simulated dataset: 92% of trips complete, 8% are cancelled (documented, adjustable ratio)

## Event Schema

| Field | Type | Description |
|---|---|---|
| `event_id` | string (UUID) | Unique identifier for this specific event |
| `event_type` | string | One of the six lifecycle event types above |
| `event_timestamp` | timestamp | When this event occurred |
| `trip_id` | string | Identifier shared across all events of the same trip |
| `driver_id` | string | Null until `DRIVER_ASSIGNED`; null for `TRIP_REQUESTED` by design |
| `vehicle_id` | string | Same nullability rule as `driver_id` |
| `pickup_zone_id` / `dropoff_zone_id` | long | NYC TLC zone identifiers |
| `pickup_datetime` / `dropoff_datetime` | timestamp | Trip-level timestamps, present on every event row |
| `distance_km` | double | Trip distance in kilometers |
| `fare_amount`, `tip_amount`, `toll_amount`, `total_amount` | double | Populated only at `TRIP_COMPLETED` / `PAYMENT_COMPLETED` |
| `surge_multiplier` | double | 1.0 for ~80% of trips (no surge), 1.1–2.5 otherwise |
| `trip_status` | string | Final terminal status (`COMPLETED` or `CANCELLED`), consistent across all events of a trip |
| `payment_type` | long | Populated only at completion/payment events |

## Design Decision: `trip_status` on Every Row

Rather than tracking a distinct per-event status, every event row for a given trip carries the same **final terminal status**. This is a deliberate simplification: it means a single Silver-layer scan can determine a trip's outcome without needing to find the terminal event first, which simplifies downstream Gold aggregations. The trade-off is documented rather than hidden — a production system might instead track status transitions explicitly per event.

## Controlled Bad Data Injection

To simulate realistic data quality problems, the following issues are injected at documented rates (applied after event generation, before batching):

| Issue | Rate | Mechanism |
|---|---|---|
| Duplicate events | 0.5% | Row sampled and unioned back into the stream (same `event_id`) |
| Late events | 0.3% | `event_timestamp` shifted 6 hours into the past |
| Invalid fares | 0.2% | `fare_amount` negated |
| Missing IDs | 0.2% | `driver_id` set to null |
| Invalid timestamps | 0.1% | `dropoff_datetime` set before `pickup_datetime` |
| Anomalies (speed/fare) | 0.2% | `distance_km` × 25 or `fare_amount` × 50 |
| Unknown zones | 0.05% | `pickup_zone_id` set to sentinel value `9999` |

These rates are intentionally small and documented — they simulate realistic noise on top of a mostly-clean synthetic stream, not a majority-corrupt dataset. All figures are configurable constants in `anomaly_injector.py`.

## Batch Delivery

Events are grouped into batches of ~1,000 records and written as `batch_000001.json`, `batch_000002.json`, etc. to the landing volume, simulating a near-real-time replay of historical data rather than a live stream. Auto Loader picks these up incrementally.