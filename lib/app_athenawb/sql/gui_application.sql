------------------------------------------------------------------------
-- TITLE:
--    gui_application.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views
--
--    This file is loaded by scenario.tcl!
--
--    GUI views translate the internal data formats of the scenariodb(n)
--    tables into presentation format.  They are defined here instead of
--    in scenariodb(n) so that they can contain application-specific
--    SQL functions.
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- ORDER VIEWS 

-- gui_cif: All orders in the CIF, with undo stack data.
CREATE TEMPORARY VIEW gui_cif AS
SELECT id                                            AS id,
       time                                          AS tick,
       timestr(time)                                 AS week,
       name                                          AS name,
       narrative                                     AS narrative,
       parmdict                                      AS parmdict
FROM cif
ORDER BY id DESC;


------------------------------------------------------------------------
-- SIGNIFICANT EVENTS VIEWS

-- gui_sigevents: All logged significant events
CREATE TEMPORARY VIEW gui_sigevents AS
SELECT event_id                                        AS event_id,
       level                                           AS level,
       t                                               AS t,
       timestr(t)                                      AS week,
       component                                       AS component,
       mklinks(narrative)                              AS narrative
FROM sigevents;


-- gui_sigevents_wtag: significant events with tags.
CREATE TEMPORARY VIEW gui_sigevents_wtag AS
SELECT event_id                                        AS event_id,
       level                                           AS level,
       t                                               AS t,
       timestr(t)                                      AS week,
       component                                       AS component,
       mklinks(narrative)                              AS narrative,
       tag                                             AS tag
FROM sigevents_view;
     
------------------------------------------------------------------------
-- SCRIPTS VIEWS

-- gui_scripts: order by sequence
CREATE TEMPORARY VIEW gui_scripts AS
SELECT name                       AS name,
       seq                        AS seq,
       yesno(auto)                AS auto,
       body                       AS body
FROM scripts
ORDER BY seq ASC;


-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------



