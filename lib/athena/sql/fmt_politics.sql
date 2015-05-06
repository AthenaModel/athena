------------------------------------------------------------------------
-- TITLE:
--    fmt_politics.sql
--
-- AUTHOR:
--    Dave Hanks
--
-- DESCRIPTION:
--    SQL Schema: Athena-specific formatted views, Politics area
--
--    This file is loaded by athenadb.tcl!
--
--    Formatted views translate the internal data formats of the scenariodb(n)
--    tables into presentation format.  They are defined here instead of
--    in scenariodb(n) so that they can contain Athena-specific
--    SQL functions.
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- POLITICS VIEWS

-- fmt_supports: Support of one actor by another in neighborhoods.
CREATE TEMPORARY VIEW fmt_supports AS
SELECT n                                             AS n,
       a                                             AS a,
       CASE WHEN supports = a     THEN 'SELF'
            WHEN supports IS NULL THEN 'NONE'
            ELSE supports 
            END                                      AS supports
FROM supports_na;


-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------

