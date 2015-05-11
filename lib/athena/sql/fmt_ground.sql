------------------------------------------------------------------------
-- TITLE:
--    fmt_ground.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views, Ground area
--
--    This file is loaded by athenadb.tcl!
--
--    Formatted views translate the internal data formats of the scenariodb(n)
--    tables into presentation format.  They are defined here instead of
--    in scenariodb(n) so that they can contain application-specific
--    SQL functions.
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- PERSONNEL VIEWS

-- fmt_units: All active units.
CREATE TEMPORARY VIEW fmt_units AS
SELECT u                  AS id,
       u                  AS u,
       tactic_id          AS tactic_id,
       n                  AS n,
       g                  AS g,
       gtype              AS gtype,
       a                  AS a,
       personnel          AS personnel,
       mgrs(location)     AS location
FROM units
WHERE active;


------------------------------------------------------------------------
-- ABSTRACT SITUATIONS VIEWS

-- gui_absits: All abstract situations
CREATE TEMPORARY VIEW fmt_absits AS
SELECT s                                              AS id,
       s || ' -- ' || stype || ' in '|| n             AS longid,
       s                                              AS s,
       state                                          AS state,
       stype                                          AS stype,
       n                                              AS n,
       format('%6.4f',coverage)                       AS coverage,
       timestr(ts)                                    AS ts,
       mgrs(location)                                 AS location,
       resolver                                       AS resolver,
       rduration                                      AS rduration,
       timestr(tr)                                    AS tr,
       inception                                      AS inception,
       -- Null for g since it's deprecated
       NULL                                           AS g
FROM absits;

-- gui_absits subview: absits in INITIAL state
CREATE TEMPORARY VIEW fmt_absits_initial AS
SELECT * FROM fmt_absits
WHERE state = 'INITIAL';

-- gui_absits subview: ONGOING 
CREATE TEMPORARY VIEW fmt_absits_ongoing AS
SELECT * FROM fmt_absits
WHERE state = 'ONGOING';

-- gui_absits subview: RESOLVED 
CREATE TEMPORARY VIEW fmt_absits_resolved AS
SELECT * FROM fmt_absits
WHERE state = 'RESOLVED';

-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------



