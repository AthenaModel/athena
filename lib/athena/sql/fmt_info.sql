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

-- fmt_caps: All Communication Asset Packages
CREATE TEMPORARY VIEW fmt_caps AS 
SELECT k                                           AS k,
       longname                                    AS longname,
       owner                                       AS owner,
       format('%4.2f',capacity)                    AS capacity,
       moneyfmt(cost)                              AS cost
FROM caps;

-- fmt_cap_kn: CAP neighborhood coverage records
CREATE TEMPORARY VIEW fmt_cap_kn AS
SELECT k || ' ' || n          AS id,
       k                      AS k,
       n                      AS n,
       format('%4.2f',nbcov)  AS nbcov
FROM cap_kn_view;

-- fmt_cap_kn subview: cap_kn's with non-zero coverage
CREATE TEMPORARY VIEW fmt_cap_kn_nonzero AS
SELECT * FROM fmt_cap_kn
WHERE CAST (nbcov AS REAL) > 0.0;

-- fmt_capcov: CAP coverage
CREATE TEMPORARY VIEW fmt_capcov AS
SELECT k || ' ' || g                                   AS id,
       k                                               AS k,
       owner                                           AS owner,
       format('%4.2f',capacity)                        AS capacity,
       g                                               AS g,
       n                                               AS n,
       format('%4.2f',nbcov)                           AS nbcov,
       format('%4.2f',pen)                             AS pen,
       format('%4.2f',capcov)                          AS capcov,
       nbcov                                           AS raw_nbcov,
       pen                                             AS raw_pen,
       capcov                                          AS raw_capcov,
       CASE WHEN pen > 0.0 AND nbcov = 0.0 
       THEN 1 ELSE 0 END                               AS orphan
FROM capcov;

-- fmt_capcov subview: capcov records, excluding zero capcov
CREATE TEMPORARY VIEW fmt_capcov_nonzero AS
SELECT * FROM fmt_capcov
WHERE raw_capcov > 0.0;

------------------------------------------------------------------------
-- SEMANTIC HOOK VIEWS
CREATE TEMPORARY VIEW fmt_hooks AS
SELECT hook_id                                   AS hook_id,
       longname                                  AS longname,
       pair(longname,hook_id)                    AS fancy,
       hook_narrative(hook_id)                   AS narrative
FROM hooks;

CREATE TEMPORARY VIEW gui_hook_topics AS
SELECT hook_id || ' ' || topic_id               AS id,
       link('/app/hook/' || hook_id, hook_id)   AS hlink,
       hook_id                                  AS hook_id,
       topic_id                                 AS topic_id,
       pair(topicname(topic_id), topic_id)      AS fancy,
       qposition(position) || ' ' || 
              topicname(topic_id)               AS narrative,
       state                                    AS state,
       format('%4.2f',position)                 AS position,
       position                                 AS raw_position
FROM hook_topics;

-----------------------------------------------------------------------
-- IOM VIEWS

CREATE TEMPORARY VIEW fmt_ioms AS
SELECT I.iom_id                                       AS iom_id,
       I.longname                                     AS longname,
       I.hook_id                                      AS hook_id,
       pair(I.longname, I.iom_id)                     AS fancy,
       CASE WHEN I.hook_id IS NULL
       THEN I.longname || '  (no hook specified)'
       ELSE I.longname || '  (' || 'Hook ' || I.hook_id || ': ' || 
            coalesce(H.narrative, 'TBD') || ')'
       END                                            AS narrative,
       state                                          AS state
FROM ioms AS I
LEFT OUTER JOIN fmt_hooks AS H USING (hook_id);
       
-----------------------------------------------------------------------
-- PAYLOAD TYPE VIEWS

-- fmt_payloads: All payloads
CREATE TEMPORARY VIEW fmt_payloads AS
SELECT iom_id || ' ' || payload_num             AS id,
       iom_id                                   AS iom_id,
       payload_num                              AS payload_num,
       payload_type                             AS payload_type,
       narrative                                AS narrative,
       state                                    AS state,
       a                                        AS a,
       c                                        AS c,
       g                                        AS g,
       format('%.1f',mag)                       AS mag
FROM payloads;
     
-- fmt_payloads_COOP: All COOP payloads
CREATE TEMPORARY VIEW fmt_payloads_COOP AS
SELECT id             AS id,
       iom_id         AS iom_id,
       payload_num    AS payload_num,
       payload_type   AS payload_type,
       narrative      AS narrative,
       state          AS state,
       g              AS g,
       mag            AS mag
FROM fmt_payloads 
WHERE payload_type='COOP';
      

-- fmt_payloads_HREL: All HREL payloads
CREATE TEMPORARY VIEW fmt_payloads_HREL AS
SELECT id             AS id,
       iom_id         AS iom_id,
       payload_num    AS payload_num,
       payload_type   AS payload_type,
       narrative      AS narrative,
       state          AS state,
       g              AS g,
       mag            AS mag
FROM fmt_payloads 
WHERE payload_type='HREL';
      

-- fmt_payloads_SAT: All SAT payloads
CREATE TEMPORARY VIEW fmt_payloads_SAT AS
SELECT id             AS id,
       iom_id         AS iom_id,
       payload_num    AS payload_num,
       payload_type   AS payload_type,
       narrative      AS narrative,
       state          AS state,
       c              AS c,
       mag            AS mag
FROM fmt_payloads 
WHERE payload_type='SAT';
       

-- gui_payloads_VREL: All VREL payloads
CREATE TEMPORARY VIEW fmt_payloads_VREL AS
SELECT id             AS id, 
       iom_id         AS iom_id,
       payload_num    AS payload_num,
       payload_type   AS payload_type,
       narrative      AS narrative,
       state          AS state,
       a              AS a,
       mag            AS mag
FROM fmt_payloads 
WHERE payload_type='VREL';
      
-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------

