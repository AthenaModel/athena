------------------------------------------------------------------------
-- TITLE:
--    web_scenario.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views, Scenario Data
--
--    This file is loaded by case.tcl!
--
--    GUI views translate the internal data formats of the scenariodb(n)
--    tables into presentation format.  They are defined here instead of
--    in scenariodb(n) so that they can contain application-specific
--    SQL functions.
--
------------------------------------------------------------------------

------------------------------------------------------------------------
-- ACTORS

-- web_actors: URLs
CREATE TEMPORARY VIEW web_actors AS
SELECT *,
       qid || '/index.html'                         AS url,
       CASE WHEN supports_qid != ''
            THEN supports_qid || '/index.html'
            ELSE ''
            END                                     AS supports_url
FROM fmt_actors;

------------------------------------------------------------------------
-- NEIGHBORHOODS

-- web_neighborhoods: URLs and QIDs (as needed)
CREATE TEMPORARY VIEW web_nbhoods AS
SELECT *,
       qid || '/index.html'                        AS url,
       CASE WHEN controller != 'NONE'
            THEN 'actor/' || controller
            ELSE ''
            END                                    AS controller_qid,
       CASE WHEN controller != 'NONE'
            THEN 'actor/' || controller || '/index.html'
            ELSE ''
            END                                    AS controller_url       
FROM fmt_nbhoods;

------------------------------------------------------------------------
-- GROUPS

CREATE TEMPORARY VIEW web_groups AS
SELECT *,
       qid   || '/index.html'                      AS url,
       CASE WHEN a_qid != ''
            THEN a_qid || '/index.html'
            ELSE ''
            END                                    AS a_url
FROM fmt_groups;

-- web_civgroups: Civilian group data 
CREATE TEMPORARY VIEW web_civgroups AS
SELECT *,
       qid   || '/index.html'                      AS url,
       n_qid || '/index.html'                      AS n_url
FROM fmt_civgroups;

-- web_frcgroups: Force group data
CREATE TEMPORARY VIEW web_frcgroups AS
SELECT *,
       qid || '/index.html'                        AS url,
       CASE WHEN a_qid != ''
            THEN a_qid || '/index.html'
            ELSE ''
            END                                    AS a_url
FROM fmt_frcgroups;

-- web_orggroups: Organization Group data
CREATE TEMPORARY VIEW web_orggroups AS
SELECT *,
       qid || '/index.html'                        AS url,
       CASE WHEN a_qid != ''
            THEN a_qid || '/index.html'
            ELSE ''
            END                                    AS a_url
FROM fmt_orggroups;

-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------


