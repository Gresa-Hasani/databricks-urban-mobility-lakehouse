# Dashboard: Demand Intelligence

**Audience**: `mobility_operations`, `mobility_analysts`, `mobility_data_engineers`
**Source**: `gold.zone_demand_5min`

## Purpose

Zone-level and time-of-day demand analysis, used to identify supply/demand imbalances across the service area.

## Visuals

| Visual | Description | Dataset |
|---|---|---|
| Table | All zones with total requests and average demand/supply ratio | `demand_by_zone` |
| Table | Zones currently flagged `CRITICAL` demand level, sorted by demand/supply ratio | `critical_zones` |
| Bar chart | Top 10 pickup zones by total requests | `top_pickup_zones` |
| Line chart | Total requests by hour of day | `demand_by_hour` |
| Bar/pie chart | Total requests and average demand/supply ratio by borough | `demand_by_borough` |

## Demand Level Thresholds

`demand_level` is computed in `gold.zone_demand_5min` from `demand_supply_ratio` (trip requests ÷ active drivers in a 5-minute window):

| Ratio | Level |
|---|---|
| < 1.0 | LOW |
| 1.0 – 2.0 | NORMAL |
| 2.0 – 4.0 | HIGH |
| > 4.0 | CRITICAL |

These thresholds are documented, fixed values — not derived from the data — and can be recalibrated with real operational data in a production deployment.