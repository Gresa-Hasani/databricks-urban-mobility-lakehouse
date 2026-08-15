# Governance & Security

## Access Model

Three Unity Catalog groups were created to model role-based access, reflecting how a real mobility platform would separate responsibilities:

| Group | Access | Rationale |
|---|---|---|
| `mobility_data_engineers` | Full access to Bronze, Silver, Gold, Quarantine, Monitoring (`USE CATALOG`, `USE SCHEMA`, `ALL PRIVILEGES` on every schema) | Engineers need to debug across every layer, including raw and quarantined data |
| `mobility_analysts` | `SELECT` on the entire `gold` schema only | Analysts consume business-ready data products; they have no need for and no access to raw or quarantined records |
| `mobility_operations` | `SELECT` on three specific Gold tables: `zone_demand_5min`, `daily_mobility_kpis`, `trip_anomalies` | Operations staff need real-time operational visibility, not full analytics access (e.g., no need for `driver_performance` or `route_performance`) |

Grants are defined in `sql/02_permissions.sql` and were applied against real Unity Catalog groups created for this project.

## PII Protection

Driver contact information (`email`) in `silver.drivers` is protected via a Unity Catalog column mask:

```sql
CREATE OR REPLACE FUNCTION urban_mobility.silver.mask_email(email STRING)
RETURNS STRING
RETURN CASE
    WHEN is_member('mobility_data_engineers') THEN email
    ELSE CONCAT('***', RIGHT(email, LENGTH(email) - POSITION('@' IN email) + 1))
END;

ALTER TABLE urban_mobility.silver.drivers
ALTER COLUMN email SET MASK urban_mobility.silver.mask_email;
```

Members of `mobility_data_engineers` see the full email address; every other role sees a masked version (e.g., `***@mobilitydrivers.com`).

Beyond column masking, PII exposure is minimized architecturally: `gold.driver_performance` — the table analysts and operations actually query — includes only `driver_id` and aggregated performance metrics. Name, email, and phone number never appear in any Gold table by design, so masking the Silver-layer column is a defense-in-depth measure, not the only protection.

## Lineage

Unity Catalog automatically tracks table- and notebook-level lineage from every query executed against catalog-managed tables — no manual configuration required. Verified via the Catalog Explorer "Lineage" tab on `silver.trips_enriched`, which correctly shows all six Gold tables built from it as downstream dependents. This lineage graph is included as a screenshot in this repository (`images/lineage.png`) and provides an audit trail from raw ingestion through to business-facing dashboards.

## Why Governance Is Built In, Not Bolted On

Access control, PII masking, and lineage were implemented as part of the core pipeline (not a later addition) because a data platform handling driver personal information has to satisfy governance requirements from the start — retrofitting access control after data has already been broadly readable is both harder and riskier than designing for it from the first table created.