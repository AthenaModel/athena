------------------------------------------------------------------------
-- TITLE:
--    fmt_sigevents.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Formatted views, sigevents data
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
-- SIGNIFICANT EVENTS VIEWS

-- fmt_sigevents: All logged significant events
CREATE TEMPORARY VIEW fmt_sigevents AS
SELECT event_id                               AS event_id,
       level                                  AS level,
       t                                      AS t,
       timestr(t)                             AS week,
       component                              AS component,
       narrative                              AS narrative
FROM sigevents;


-- fmt_sigevents_wtag: significant events with tags.
CREATE TEMPORARY VIEW fmt_sigevents_wtag AS
SELECT event_id                               AS event_id,
       level                                  AS level,
       t                                      AS t,
       timestr(t)                             AS week,
       component                              AS component,
       narrative                              AS narrative,
       tag                                    AS tag
FROM sigevents_view;

-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------


