------------------------------------------------------------------------
-- TITLE:
--    service_temp.sql
--
-- AUTHOR:
--    Dave Hanks
--
-- DESCRIPTION:
--    Temporary SQL Schema for service(sim).
--
--------------------------------

-- Temporary Table: Saturation/Required Service funding levels
CREATE TEMP TABLE sr_service (
    g            TEXT,              -- Group name
    req_funding  REAL DEFAULT 0.0,  -- Required Funding Level $/week
    sat_funding  REAL DEFAULT 0.0,  -- Saturation Funding Level $/week

    PRIMARY KEY (g)
);

