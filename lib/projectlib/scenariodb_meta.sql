------------------------------------------------------------------------
-- TITLE:
--    scenariodb_meta.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema for scenariodb(n): Scenario metadata.
--
--
------------------------------------------------------------------------


------------------------------------------------------------------------
-- META-DATA 

-- Scenario Table: Scenario meta-data
--
-- The notion is that it can contain arbitrary meta-data.  
-- In schema 3 and prior the table was always empty, but served
-- as a flag that this is a scenario file.  In schema 4 and following,
-- it should the following parms:
--
--   version     - The x.y.z version number of the software that
--                 created the file.
--   build       - The build number of the software that created the
--                 file.
--   versionfull - $version-$build.

CREATE TABLE scenario (
    parm  TEXT PRIMARY KEY,
    value TEXT DEFAULT ''
);


------------------------------------------------------------------------
-- End of File
------------------------------------------------------------------------
