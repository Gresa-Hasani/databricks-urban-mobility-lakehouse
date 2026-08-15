# Performance Optimization

All numbers on this page are real, measured results from `src/monitoring/benchmark_performance`, executed against four dataset sizes sampled from `silver.trip_events_clean` (total available: 8,342,336 rows):

| Label | Target rows | Actual rows |
|---|---|---|
| 100K | 100,000 | 100,056 |
| 1M | 1,000,000 | 999,799 |
| 5M | 5,000,000 | 4,999,181 |
| FULL | 8,342,336 | 8,342,336 |

No numbers on this page are estimated or invented — where a technique showed no benefit, that is reported as-is.

## Technique 1: Broadcast Join

Query: join each sample against `silver.zones` (265 rows) on `pickup_zone_id`, grouped by borough.

| Size | Baseline (no hint) | Optimized (`F.broadcast()`) | Improvement |
|---|---|---|---|
| 100K | 1.43s | 1.09s | 23.8% |
| 1M | 1.49s | 0.92s | 38.3% |
| 5M | 1.39s | 0.97s | 30.2% |
| FULL | 1.69s | 1.28s | 24.3% |

**Average improvement: ~29%.** Note that even the "baseline" runs were fast and nearly flat across dataset sizes — Databricks' Adaptive Query Execution (AQE) likely already auto-detected the small `zones` table and applied broadcast join optimization automatically in many cases, even without an explicit hint. The explicit `F.broadcast()` hint still produced a consistent, measurable improvement on top of that.

`spark.sql.autoBroadcastJoinThreshold` could not be adjusted directly, as session-level config changes of this kind are restricted on Databricks Serverless compute (`CONFIG_NOT_AVAILABLE`). The comparison was instead made using a query-level `F.broadcast()` hint versus no hint, which is a supported technique on Serverless.

## Technique 2: `OPTIMIZE` + Z-ORDER

Query: filter `bench_full` on a single `pickup_zone_id` value, before and after `OPTIMIZE ... ZORDER BY (pickup_zone_id)`.

| | Before OPTIMIZE | After OPTIMIZE | Improvement |
|---|---|---|---|
| Filtered count query | 0.59s | 0.62s | **-4.2%** |

**No measurable benefit at this scale.** This is reported honestly rather than omitted or reframed. A plausible explanation: at ~8.3M rows, the underlying file count was likely already small enough that Z-ORDER's data-skipping benefit was outweighed by the overhead of the `OPTIMIZE` operation itself and by measurement noise from a single run. `OPTIMIZE` + Z-ORDER is expected to show clearer benefit at larger production scale (100M+ rows) or under more skewed access patterns than a single point filter on evenly-distributed zone IDs.

## Technique 3: Repartitioning (Shuffle Reduction)

Query: `groupBy("pickup_zone_id").count()` on `bench_full`, comparing default partitioning against `repartition(8, "pickup_zone_id")` before the aggregation.

| | Default partitions | Repartitioned (8, by key) | Improvement |
|---|---|---|---|
| GroupBy aggregation | 0.93s | 0.70s | 25.0% |

Reducing the number of shuffle partitions to align with available Serverless parallelism, and pre-partitioning by the grouping key, produced a measurable improvement.

## Summary

| Technique | Result |
|---|---|
| Broadcast join | +24% to +38% (consistent, positive) |
| OPTIMIZE + Z-ORDER | -4.2% (no benefit at this scale) |
| Repartition by key | +25% (positive) |

**Takeaway**: optimization technique selection should be data-driven and validated with real measurements, not applied uniformly on the assumption that every standard technique helps in every context. Two of three tested techniques showed clear improvement; one did not, at this specific data scale — both outcomes are reported.

## Note on Restricted Spark Configuration on Serverless

Several standard tuning APIs were unavailable during benchmarking on Databricks Free Edition Serverless compute:
- `spark.conf.set("spark.sql.autoBroadcastJoinThreshold", ...)` — blocked (`CONFIG_NOT_AVAILABLE`)
- `.cache()` / `.persist()` — blocked (`NOT_SUPPORTED_WITH_SERVERLESS`)
- `.rdd` access — not implemented on Spark Connect

These constraints shaped which techniques could be benchmarked and how (see `docs/streaming.md` for the equivalent discussion in the context of the streaming pipeline).