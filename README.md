# Real-Time Urban Mobility Intelligence Lakehouse

[![Databricks](https://img.shields.io/badge/Databricks-FF3621?style=flat&logo=databricks&logoColor=white)](https://databricks.com)
[![Apache Spark](https://img.shields.io/badge/Apache%20Spark-E25A1C?style=flat&logo=apachespark&logoColor=white)](https://spark.apache.org)
[![Delta Lake](https://img.shields.io/badge/Delta%20Lake-00ADD4?style=flat)](https://delta.io)
[![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)](https://www.python.org)
[![Unity Catalog](https://img.shields.io/badge/Unity%20Catalog-governed-blue?style=flat)](https://www.databricks.com/product/unity-catalog)
[![Tests](https://img.shields.io/badge/tests-8%2F8%20passing-brightgreen?style=flat)](tests/)

A production-style Data Engineering portfolio project that simulates a ride-hailing platform and processes millions of trip events through a governed, tested, and orchestrated Databricks lakehouse — end to end, from raw historical taxi data to business-ready dashboards.

Built on real NYC TLC trip data, this project demonstrates the full lifecycle of a modern data platform: incremental streaming ingestion, a reusable data quality framework, incremental state management with Delta MERGE, six business-oriented Gold data products, role-based governance with PII protection, a 15-task orchestrated workflow, real performance benchmarking, and automated testing — all documented with measured results, including the parts that didn't go as planned.

---

## Table of Contents

- [Business Problem](#business-problem)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Dataset](#dataset)
- [Event Model & Simulation](#event-model--simulation)
- [Bronze / Silver / Gold](#bronze--silver--gold)
- [Data Quality, Quarantine & Deduplication](#data-quality-quarantine--deduplication)
- [Late-Event Handling](#late-event-handling)
- [Delta MERGE](#delta-merge)
- [Demand Analytics & Anomaly Detection](#demand-analytics--anomaly-detection)
- [Governance & Security](#governance--security)
- [Orchestration (Lakeflow Jobs)](#orchestration-lakeflow-jobs)
- [Monitoring](#monitoring)
- [Performance Optimization](#performance-optimization)
- [Dashboards](#dashboards)
- [Testing](#testing)
- [Results](#results)
- [Repository Structure](#repository-structure)
- [Setup Instructions](#setup-instructions)
- [Engineering Decisions](#engineering-decisions)
- [Future Improvements](#future-improvements)

---

## Business Problem

An operational mobility data platform that processes near-real-time trip events to support demand analysis, revenue analytics, driver performance monitoring, rule-based anomaly detection, data quality monitoring, governance, and pipeline observability — modeled on a ride-hailing platform similar to Uber or Bolt, built on real NYC TLC taxi trip data.

## Key Features

| | |
|---|---|
| **Streaming ingestion** | Auto Loader, incremental, restart-safe, with schema evolution support |
| **Data quality** | Reusable declarative framework, 9 rules, full quarantine audit trail |
| **Incremental state** | Delta MERGE for trip state — no full-table rebuilds |
| **Analytics** | 6 business-oriented Gold data products + rule-based anomaly detection |
| **Governance** | Unity Catalog role-based access, PII column masking, automatic lineage |
| **Orchestration** | 15-task Lakeflow Jobs DAG, retry policy, tested with a real failure + repair run |
| **Performance** | Real benchmarks across 100K–8.3M rows, both wins and non-wins reported |
| **Dashboards** | 3 Databricks SQL dashboards (Operations, Demand Intelligence, Platform Health) |
| **Testing** | 8 automated pytest tests, all passing |

## Architecture

Full data flow diagram and layer responsibilities: [`docs/architecture.md`](docs/architecture.md)

```
NYC TLC Historical Data → Trip Event Simulator → Landing Volume (JSON batches)
    → Auto Loader → Bronze → Silver (clean, state, enriched) → Gold (6 tables)
                        |
                   Quarantine (invalid records, never dropped)
                        |
                   Monitoring (pipeline runs, DQ results, streaming metrics)
                        |
            Databricks SQL Dashboards <- Lakeflow Jobs (15-task orchestration)
```

## Technology Stack

Databricks (Free Edition, Serverless) · Apache Spark · PySpark · Spark Structured Streaming · Delta Lake · Databricks Auto Loader · Unity Catalog · Lakeflow Jobs · Databricks SQL · Python · pytest · Git / GitHub

## Dataset

| | |
|---|---|
| Source | NYC TLC Yellow Taxi trip records, January–February 2026 (~7.12M real trips, public dataset) |
| Sampled | ~1.8M trips → 8,751,802 lifecycle events after bad-data injection |
| Reference data | 10,000 synthetic drivers, 10,000 synthetic vehicles (1:1 assignment), 265 real NYC TLC zones |

Full table schemas: [`docs/data_model.md`](docs/data_model.md)

## Event Model & Simulation

Each trip is a sequence of lifecycle events — `TRIP_REQUESTED → DRIVER_ASSIGNED → TRIP_STARTED → TRIP_COMPLETED → PAYMENT_COMPLETED`, or `→ TRIP_CANCELLED` — generated from real historical trip data by `src/simulator/trip_event_simulator.py`, with controlled, documented bad-data injection (duplicates, late events, invalid fares, missing IDs, anomalies, unknown zones) via `src/simulator/anomaly_injector.py`.

Full schema and injection rates: [`docs/event_model.md`](docs/event_model.md)

## Bronze / Silver / Gold

| Layer | Role |
|---|---|
| **Bronze** | Raw ingestion via Auto Loader, no transformation, full audit metadata |
| **Silver** | Typed, deduplicated (watermarked), joined with reference data, enriched with derived features |
| **Gold** | `zone_demand_5min`, `hourly_revenue`, `driver_performance`, `route_performance`, `daily_mobility_kpis`, `trip_anomalies` |

Full table-by-table breakdown: [`docs/data_model.md`](docs/data_model.md)

## Data Quality, Quarantine & Deduplication

A reusable rules/validator framework (`src/quality/`) checks 9 conditions per event; failing records are quarantined with the specific rule failed, reason, and full raw payload — never silently dropped. Deduplication (watermarked `dropDuplicates`) was verified empirically: clean + quarantined records summed exactly to the pre-duplication event count.

Full details, including a real rule gap found and fixed during development: [`docs/data_quality.md`](docs/data_quality.md)

## Late-Event Handling

Event-time watermarking (`withWatermark`, 2-hour delay) bounds streaming state for deduplication. Late events (0.3% injected, shifted 6 hours back) are detectable via the Platform Health dashboard. The difference between batch-replay and continuous-streaming watermark behavior is documented honestly in [`docs/streaming.md`](docs/streaming.md).

## Delta MERGE

`silver.trips_current` is built incrementally via Delta `MERGE` (`whenMatchedUpdateAll` / `whenNotMatchedInsertAll`) rather than full-table rebuilds — the standard pattern for maintaining current-state tables from an event stream at scale.

## Demand Analytics & Anomaly Detection

`gold.zone_demand_5min` computes 5-minute windowed demand/supply ratios with documented thresholds (LOW / NORMAL / HIGH / CRITICAL). `gold.trip_anomalies` uses hybrid statistical + business-rule thresholds (99.5th percentile floored by a physically-reasonable absolute minimum) — after an initial pure 3-sigma approach proved non-robust to the very outliers it was meant to detect.

Both iterations documented: [`docs/performance.md`](docs/performance.md), [`docs/data_quality.md`](docs/data_quality.md)

## Governance & Security

Three Unity Catalog groups — `mobility_data_engineers`, `mobility_analysts`, `mobility_operations` — with scoped grants, driver email column masking, and automatic Unity Catalog lineage.

Full detail: [`docs/governance.md`](docs/governance.md)

## Orchestration (Lakeflow Jobs)

A 15-task Lakeflow Jobs DAG (`workflows/urban_mobility_job.yml`) orchestrates the full pipeline from parallel reference-data ingestion through 6 parallel Gold tasks, with a configured retry policy. Tested end-to-end with a real failure (misconfigured compute on `route_performance`) resolved via Repair Run — documented with actual run data, not staged.

## Monitoring

`monitoring.pipeline_runs`, `monitoring.data_quality_results`, and `monitoring.streaming_metrics` capture real execution data from production runs, not simulated placeholders.

Details: [`docs/monitoring.md`](docs/monitoring.md)

## Performance Optimization

Three techniques benchmarked with real measurements across 100K–8.3M row datasets:

| Technique | Result |
|---|---|
| Broadcast join | +24% to +38% |
| Repartition by key | +25% |
| `OPTIMIZE` + Z-ORDER | -4.2% (no benefit at this scale, reported as-is) |

Full numbers and methodology: [`docs/performance.md`](docs/performance.md)

## Dashboards

| Dashboard | Focus | Source |
|---|---|---|
| Operations Command Center | Daily KPIs | Gold |
| Demand Intelligence | Zone / time / borough demand | Gold |
| Platform Health | Pipeline observability | Bronze / Quarantine / Monitoring (intentionally, not Gold) |

Details: [`dashboards/`](dashboards/)

## Testing

8 automated pytest tests (`tests/`) covering negative fares, missing trip IDs, duplicate removal, valid event acceptance, trip duration calculation, impossible speed detection, revenue calculation, and latest trip state selection.

```
pytest tests/
```

**Result: 8 / 8 passing**

## Results

Real, measured results from the completed implementation — no fabricated numbers.

| Metric | Value |
|---|---|
| Total events processed (Bronze) | 8,751,802 |
| Clean events (Silver) | 8,342,336 |
| Invalid records quarantined | 366,089 |
| Duplicate events removed | 43,377 |
| Unique trips | 1,736,194 |
| Drivers | 10,000 |
| Vehicles | 10,000 |
| Zones | 265 |
| Gold tables created | 6 |
| Monitoring tables | 3 |
| Lakeflow Jobs tasks | 15 |
| Automated tests passing | 8 / 8 |
| Broadcast join improvement | +24% to +38% |
| Repartition improvement | +25% |
| OPTIMIZE + Z-ORDER result | -4.2% (no benefit at this scale) |

## Repository Structure

```
├── config/                  dev/prod environment configuration
├── src/
│   ├── simulator/            event generation + bad data injection
│   ├── ingestion/             Auto Loader / batch ingestion into Bronze
│   ├── silver/                 cleaning, trip state, enrichment
│   ├── quality/                 rules + validator framework
│   ├── gold/                     6 business data products
│   └── monitoring/               pipeline/streaming metrics + benchmarks
├── sql/                      catalog setup, permissions
├── tests/                    pytest suite
├── workflows/                 Lakeflow Jobs definition
├── dashboards/                 dashboard documentation
├── docs/                       architecture, data model, quality, governance, etc.
└── images/                     screenshots (lineage, job runs, dashboards)
```

## Setup Instructions

1. Create a Databricks workspace (Free Edition or higher) with Unity Catalog enabled
2. Run `sql/01_catalog_setup.sql` to create the catalog, schemas, and volumes
3. Download NYC TLC Yellow Taxi trip data and upload to the `bronze.source_data` volume
4. Run `src/simulator/driver_generator` and `vehicle_generator`, then `src/ingestion/ingest_drivers`, `ingest_vehicles`, `ingest_zones`
5. Run `src/simulator/trip_event_simulator` to generate and batch trip events
6. Run `src/ingestion/ingest_trip_events` (Auto Loader)
7. Run `src/silver/clean_trip_events` → `build_trip_state` → `enrich_trips`
8. Run each notebook in `src/gold/`
9. Run `sql/02_permissions.sql` for governance setup
10. Import `workflows/urban_mobility_job.yml` as a Lakeflow Job to orchestrate steps 5–8 going forward
11. Run tests locally: `pytest tests/`

## Engineering Decisions

- **Auto Loader** over plain batch reads — incremental file discovery, schema evolution, restart safety
- **Delta Lake + MERGE** — reliable incremental updates to `trips_current` without full-table rebuilds
- **Watermarking** — bounds streaming state for deduplication; batch-replay vs. continuous-streaming trade-offs documented, not hidden
- **Quarantine over drop** — invalid records are auditable and recoverable, never silently lost
- **Gold as business-oriented data products** — each table answers a specific business question, not a generic dump
- **Hybrid statistical + business-rule anomaly thresholds** — a pure statistical (3-sigma) approach was tested first, found non-robust to the very outliers it was meant to catch, and corrected; this iteration is documented rather than presented as the first and only approach
- **`availableNow` trigger over continuous streaming** — appropriate for Free Edition serverless compute; equivalent behavior achieved via scheduled Lakeflow Jobs execution

## Future Improvements

- Parametrize notebooks to read from `config/dev.yml` / `prod.yml` rather than hard-coded values
- Recalibrate demand-level thresholds using real operational data rather than fixed constants
- Extend performance benchmarking to true 100M+ row scale to properly evaluate `OPTIMIZE` + Z-ORDER
- Add a scheduled trigger to Lakeflow Jobs for continuous (non-`availableNow`) operation
- Fix the vehicle-to-driver random-assignment logic at the source generation layer for guaranteed uniform coverage by design, rather than relying on post-hoc correction (already fixed once during development — see [`docs/data_quality.md`](docs/data_quality.md) for the birthday-paradox root cause found)

---

## Author

**[Gresa Hasani](https://github.com/Gresa-Hasani)**