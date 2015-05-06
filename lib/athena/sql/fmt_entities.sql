------------------------------------------------------------------------
-- TITLE:
--    fmt_application.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Applications Entities
--
--    This file is loaded by athenadb.tcl!
--
--    Formatted views translate the internal data formats of the 
--    scenariodb(n) tables into presentation format.  They are defined 
--    here instead of in scenariodb(n) so that they can contain 
--    application-specific SQL functions.
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- PRIMARY ENTITIES

-- entities: Primary entity IDs and reserved words.
-- 
-- Any primary entity's ID must be unique in the scenario.  This
-- view creates a list of primary entity IDs, so that we can verify 
-- this, and retrieve the entity type for a given ID.  The list
-- includes a number of reserved words.
--
-- Note: The agents table includes all actors.

CREATE TEMPORARY VIEW entities AS
SELECT 'PLAYBOX'  AS id, 'reserved' AS etype                  UNION
SELECT 'CIV'      AS id, 'reserved' AS etype                  UNION
SELECT 'FRC'      AS id, 'reserved' AS etype                  UNION
SELECT 'ORG'      AS id, 'reserved' AS etype                  UNION
SELECT 'ALL'      AS id, 'reserved' AS etype                  UNION
SELECT 'NONE'     AS id, 'reserved' AS etype                  UNION
SELECT 'SELF'     AS id, 'reserved' AS etype                  UNION
SELECT n          AS id, 'nbhood'   AS etype FROM nbhoods     UNION
SELECT agent_id   AS id, 'agent'    AS etype FROM agents      UNION
SELECT g          AS id, 'group'    AS etype FROM groups      UNION
SELECT k          AS id, 'cap'      AS etype FROM caps        UNION
SELECT iom_id     AS id, 'iom'      AS etype FROM ioms        UNION
SELECT c          AS id, 'concern'  AS etype FROM concerns    UNION
SELECT a          AS id, 'activity' AS etype FROM activity    UNION
SELECT u          AS id, 'unit'     AS etype FROM units       UNION
SELECT curse_id   AS id, 'curse'    AS etype FROM curses      UNION
SELECT hook_id    AS id, 'hook'     AS etype FROM hooks;

-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------

