------------------------------------------------------------------------
-- TITLE:
--    gui_curses.sql
--
-- AUTHOR:
--    Dave Hanks
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views, CURSEs area
--
--    This file is loaded by app.tcl!
--
--    GUI views translate the internal data formats of the scenariodb(n)
--    tables into presentation format.  They are defined here instead of
--    in scenariodb(n) so that they can contain application-specific
--    SQL functions.
--
------------------------------------------------------------------------


------------------------------------------------------------------------
-- Complex User-defined Role-based Situations and Events (CURSE) views

-- gui_curses: All CURSEs
CREATE TEMPORARY VIEW gui_curses AS
SELECT curse_id                                    AS curse_id,
       longname                                    AS longname, 
       cause                                       AS cause,
       fancy                                       AS fancy,
       '/app/curse/' || curse_id                   AS url,
       link('/app/curse/' || curse_id, curse_id)   AS link,
       link('/app/curse/' || curse_id, longname)   AS longlink,
       narrative                                   AS narrative,
       state                                       AS state
FROM fmt_curses;

-- gui_injects*: All injects and injects by type
CREATE TEMPORARY VIEW gui_injects AS
SELECT * FROM fmt_injects;

CREATE TEMPORARY VIEW gui_injects_SAT AS
SELECT * FROM fmt_injects_SAT;

CREATE TEMPORARY VIEW gui_injects_COOP AS
SELECT * FROM fmt_injects_COOP;

CREATE TEMPORARY VIEW gui_injects_HREL AS
SELECT * FROM fmt_injects_HREL;

CREATE TEMPORARY VIEW gui_injects_VREL AS
SELECT * FROM fmt_injects_VREL;
