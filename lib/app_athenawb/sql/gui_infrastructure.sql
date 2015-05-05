------------------------------------------------------------------------
-- TITLE:
--    gui_infrastructure.sql
--
-- AUTHOR:
--    Dave Hanks
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views, Infrastructure area
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
-- INFRASTRUCTURE PLANT VIEWS
CREATE TEMPORARY VIEW gui_plants_na AS
SELECT PN.n || ' ' || PN.a                     AS id,
       PN.n                                    AS n,
       N.link                                  AS nlink,
       PN.a                                    AS a,
       '/app/plant/' || AG.agent_id        AS url,
       AG.agent_id                             AS fancy,
       coalesce(A.link,AG.link)                AS alink,
       coalesce(A.pretty_am_flag, 'Yes')       AS auto_maintain,
       format('%.2f', PN.rho)                  AS rho,
       PN.num                                  AS num
FROM plants_na             AS PN
JOIN gui_nbhoods           AS N  ON (PN.n=N.n)
LEFT OUTER JOIN gui_agents AS AG ON (PN.a=AG.agent_id)
LEFT OUTER JOIN gui_actors AS A  ON (PN.a=A.a);

CREATE TEMPORARY VIEW gui_plants_shares AS
SELECT PS.n || ' ' || PS.a                     AS id,
       PS.n                                    AS n,
       N.link                                  AS nlink,
       PS.a                                    AS a,
       A.link                                  AS alink,
       coalesce(A.pretty_am_flag, 'Yes')       AS auto_maintain,
       format('%.2f', PS.rho)                  AS rho,
       PS.num                                  AS num
FROM plants_shares         AS PS
JOIN gui_nbhoods           AS N  ON (PS.n=N.n)
LEFT OUTER JOIN gui_actors AS A  ON (PS.a=A.a);

CREATE TEMPORARY VIEW gui_plants_alloc AS
SELECT PA.n || ' ' || PA.a                     AS id,
       PA.n                                    AS n,
       PA.pcf                                  AS pcf,
       N.link                                  AS nlink,
       PA.a                                    AS a,
       '/app/plant/' || AG.agent_id        AS url,
       AG.agent_id                             AS fancy, 
       coalesce(A.link, AG.link)               AS alink,
       coalesce(A.pretty_am_flag, 'Yes')       AS auto_maintain,
       format('%.2f', PA.rho)                  AS rho,
       PA.shares                               AS shares
FROM plants_alloc_view     AS PA
JOIN gui_nbhoods           AS N  ON (PA.n=N.n)
LEFT OUTER JOIN gui_agents AS AG ON (PA.a=AG.agent_id)
LEFT OUTER JOIN gui_actors AS A  ON (PA.a=A.a);

CREATE TEMPORARY VIEW gui_plants_build AS
SELECT N.link                            AS nlink,
       B.n                               AS n,
       A.link                            AS alink,
       B.a                               AS a,
       B.levels                          AS levels,
       B.num                             AS num
FROM plants_build AS B
JOIN gui_nbhoods AS N ON (N.n=B.n)
JOIN gui_actors  AS A ON (A.a=B.a);

CREATE TEMPORARY VIEW gui_plants_n AS
SELECT N.longlink                        AS nlonglink,
       N.link                            AS nlink,
       P.n                               AS n,
       P.pcf                             AS pcf,
       P.nbpop                           AS nbpop
FROM plants_n_view AS P
JOIN gui_nbhoods AS N ON (N.n=P.n);

-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------

