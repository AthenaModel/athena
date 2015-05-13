------------------------------------------------------------------------
-- TITLE:
--    gui_info.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views, Information area
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
-- COMMUNICATIONS ASSET PACKAGE (CAP) VIEWS

-- gui_caps: All Communications Asset Packages
CREATE TEMPORARY VIEW gui_caps AS
SELECT k                                           AS id,
       k                                           AS k,
       '/app/cap/' || k                            AS url,
       pair(longname, k)                           AS fancy,
       link('/app/cap/' || k, k)                   AS link,
       link('/app/cap/' || k, pair(longname, k))   AS longlink,
       longname                                    AS longname,
       owner                                       AS owner,
       capacity                                    AS capacity,
       cost                                        AS cost
FROM fmt_caps;

CREATE TEMPORARY VIEW gui_cap_kn AS
SELECT * FROM fmt_cap_kn;

CREATE TEMPORARY VIEW gui_cap_kn_nonzero
AS SELECT * FROM fmt_cap_kn_nonzero;

-- gui_capcov: CAP group coverage.  This is used both for the 
-- CAP:PEN orders and for displaying the capcov results.
CREATE TEMPORARY VIEW gui_capcov AS
SELECT k || ' ' || g                  AS id,
       k                              AS k,
       owner                          AS owner,
       capacity                       AS capacity,
       g                              AS g,
       n                              AS n,
       link('/app/nbhood/' || n, n)   AS nlink,
       link('/app/group/'  || g, g)   AS glink,
       nbcov                          AS nbcov,
       pen                            AS pen,
       capcov                         AS capcov,
       raw_nbcov                      AS raw_nbcov,
       raw_pen                        AS raw_pen,
       raw_capcov                     AS raw_capcov,
       orphan                         AS orphan
FROM fmt_capcov;

-- gui_capcov subview: capcov records, excluding zero capcov
CREATE TEMPORARY VIEW gui_capcov_nonzero AS
SELECT * FROM gui_capcov
WHERE raw_capcov > 0.0;

-- gui_capcov subview: capcov records for orphans (pen > 0, nbcov = 0)
CREATE TEMPORARY VIEW gui_capcov_orphans AS
SELECT * FROM gui_capcov
WHERE orphan;

------------------------------------------------------------------------
-- SEMANTIC HOOK VIEWS

CREATE TEMPORARY VIEW gui_hooks AS
SELECT hook_id                                   AS hook_id,
       longname                                  AS longname,
       fancy                                     AS fancy,
       '/app/hook/' || hook_id                   AS url,
       link('/app/hook/' || hook_id, hook_id)    AS link,
       link('/app/hook/' || hook_id, 
            pair(longname, hook_id))             AS longlink,
       narrative                                 AS narrative
FROM fmt_hooks;  

-----------------------------------------------------------------------
-- IOM VIEWS

CREATE TEMPORARY VIEW gui_ioms AS
SELECT iom_id                                 AS iom_id,
       longname                               AS longname,
       hook_id                                AS hook_id,
       fancy                                  AS fancy,
       '/app/iom/' || iom_id                  AS url,
       link('/app/iom/'  || iom_id, iom_id)   AS link,
       link('/app/iom/'  || iom_id, iom_id)   AS longlink,
       link('/app/hook/' || hook_id, hook_id) AS hlink,
       narrative                              AS narrative,
       state                                  AS state
FROM fmt_ioms;

-----------------------------------------------------------------------
-- PAYLOAD TYPE VIEWS

-- gui_payloads: All payloads
CREATE TEMPORARY VIEW gui_payloads AS
SELECT * FROM fmt_payloads;

-- gui_payloads_COOP: COOP payloads
CREATE TEMPORARY VIEW gui_payloads_COOP AS
SELECT * FROM fmt_payloads_COOP;

-- gui_payloads_HREL: HREL payloads
CREATE TEMPORARY VIEW gui_payloads_HREL AS
SELECT * FROM fmt_payloads_HREL;

-- gui_payloads_SAT: SAT payloads
CREATE TEMPORARY VIEW gui_payloads_SAT AS
SELECT * FROM fmt_payloads_SAT;

-- gui_payloads_VREL: VREL payloads
CREATE TEMPORARY VIEW gui_payloads_VREL AS
SELECT * FROM fmt_payloads_VREL;

-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------

