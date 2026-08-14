%sql
GRANT USE CATALOG ON CATALOG urban_mobility TO `mobility_data_engineers`;
GRANT USE SCHEMA ON SCHEMA urban_mobility.bronze TO `mobility_data_engineers`;
GRANT USE SCHEMA ON SCHEMA urban_mobility.silver TO `mobility_data_engineers`;
GRANT USE SCHEMA ON SCHEMA urban_mobility.gold TO `mobility_data_engineers`;
GRANT USE SCHEMA ON SCHEMA urban_mobility.quarantine TO `mobility_data_engineers`;
GRANT USE SCHEMA ON SCHEMA urban_mobility.monitoring TO `mobility_data_engineers`;
GRANT ALL PRIVILEGES ON SCHEMA urban_mobility.bronze TO `mobility_data_engineers`;
GRANT ALL PRIVILEGES ON SCHEMA urban_mobility.silver TO `mobility_data_engineers`;
GRANT ALL PRIVILEGES ON SCHEMA urban_mobility.gold TO `mobility_data_engineers`;
GRANT ALL PRIVILEGES ON SCHEMA urban_mobility.quarantine TO `mobility_data_engineers`;
GRANT ALL PRIVILEGES ON SCHEMA urban_mobility.monitoring TO `mobility_data_engineers`;

GRANT USE CATALOG ON CATALOG urban_mobility TO `mobility_analysts`;
GRANT USE SCHEMA ON SCHEMA urban_mobility.gold TO `mobility_analysts`;
GRANT SELECT ON SCHEMA urban_mobility.gold TO `mobility_analysts`;

GRANT USE CATALOG ON CATALOG urban_mobility TO `mobility_operations`;
GRANT USE SCHEMA ON SCHEMA urban_mobility.gold TO `mobility_operations`;
GRANT SELECT ON TABLE urban_mobility.gold.zone_demand_5min TO `mobility_operations`;
GRANT SELECT ON TABLE urban_mobility.gold.daily_mobility_kpis TO `mobility_operations`;
GRANT SELECT ON TABLE urban_mobility.gold.trip_anomalies TO `mobility_operations`;

CREATE OR REPLACE FUNCTION urban_mobility.silver.mask_email(email STRING)
RETURNS STRING
RETURN CASE
    WHEN is_member('mobility_data_engineers') THEN email
    ELSE CONCAT('***', RIGHT(email, LENGTH(email) - POSITION('@' IN email) + 1))
END;

ALTER TABLE urban_mobility.silver.drivers
ALTER COLUMN email SET MASK urban_mobility.silver.mask_email;