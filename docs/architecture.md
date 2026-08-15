# Architecture

## Business Problem

Real-Time Urban Mobility Intelligence Lakehouse is an operational data platform that processes near-real-time trip events from a ride-hailing-style platform (modeled on NYC taxi operations) to support:

- Demand analysis and zone-level supply/demand balancing
- Revenue analytics (hourly, daily, per-route)
- Driver performance monitoring
- Rule-based anomaly detection (impossible speeds, extreme fares, fare-distance mismatches)
- Data quality monitoring and governed access to sensitive data
- Pipeline observability and orchestration monitoring

## High-Level Data Flow

```
NYC TLC Historical Data (source)
        │
        ▼
Trip Event Simulator (Python + PySpark)
  - Transforms historical trips into lifecycle events
  - Injects controlled bad data (duplicates, late events, invalid fares, missing IDs, anomalies)
        │
        ▼
Landing Zone (Unity Catalog Volume, JSON batches)
        │
        ▼
Auto Loader (cloudFiles, Structured Streaming)
        │
        ▼
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   BRONZE    │────▶│    SILVER    │────▶│    GOLD     │
│ Raw, as-is  │     │ Clean, typed,│     │  Business   │
│ + metadata  │     │ deduplicated,│     │  data       │
│             │     │ enriched     │     │  products   │
└─────────────┘     └──────────────┘     └─────────────┘
        │                   │
        ▼                   ▼
   QUARANTINE          MONITORING
 (invalid records,   (pipeline runs, DQ
  never dropped)       results, streaming
                        metrics)
        │
        ▼
Databricks SQL Dashboards (Operations, Demand Intelligence, Platform Health)
        │
        ▼
Lakeflow Jobs (orchestrates the entire flow above, 15 tasks, dependency-managed)
```

## Layer Responsibilities

- **Bronze**: raw ingestion, close to source, no business transformation. Includes `_source_file` and `_ingested_at` metadata for auditability.
- **Silver**: type casting, standardization, deduplication (watermarked), reference joins, derived features (trip duration, speed, revenue/km, time-of-day flags).
- **Gold**: six business-oriented data products — zone demand, hourly revenue, driver performance, route performance, daily KPIs, and rule-based anomaly detection.
- **Quarantine**: invalid records with the specific rule(s) they failed, raw payload preserved — never silently dropped.
- **Monitoring**: pipeline run history and streaming query metrics, captured from real executions.

## Technology Stack

- **Compute**: Databricks Free Edition, Serverless
- **Processing**: Apache Spark, PySpark, Spark Structured Streaming
- **Storage**: Delta Lake, Unity Catalog Volumes
- **Ingestion**: Databricks Auto Loader (cloudFiles)
- **Governance**: Unity Catalog (catalog/schema/table grants, column masking, automatic lineage)
- **Orchestration**: Lakeflow Jobs (15-task DAG with retry policy)
- **Analytics**: Databricks SQL, Databricks SQL Dashboards
- **Testing**: pytest

## Dataset Scale

- Source: NYC TLC Yellow Taxi trip records, January–February 2026 (~7.12M real trips)
- Sampled: ~1.8M trips → ~8.7M lifecycle events (within the 5–10M target range)
- Reference data: 10,000 synthetic drivers, 10,000 synthetic vehicles, 265 real NYC TLC zones
