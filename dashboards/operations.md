# Dashboard: Operations Command Center

**Audience**: `mobility_operations`, `mobility_data_engineers`
**Source**: `gold.daily_mobility_kpis`

## Purpose

A single-page summary of the platform's operational state, intended for day-to-day monitoring of trip volume, revenue, and service quality.

## Visuals

| Visual | Metric | Source column |
|---|---|---|
| Counter | Trips Today | `trip_requests` |
| Counter | Completed Trips | `completed_trips` |
| Counter | Active Drivers | `active_drivers` |
| Counter | Revenue Today | `revenue_today` (formatted as currency) |
| Counter | Average Fare | `avg_fare` (formatted as currency) |
| Counter | Cancellation Rate | `cancellation_rate` (formatted as percentage) |

## Note on "Today"

Because the underlying dataset is a historical replay (NYC TLC trips, January–February 2026) rather than a live feed, "today" is defined as the most recent date present in `gold.daily_mobility_kpis`:

```sql
WHERE date = (SELECT MAX(date) FROM urban_mobility.gold.daily_mobility_kpis)
```

In a production deployment with a live Lakeflow Jobs schedule, this same query would reflect the actual current day without modification.