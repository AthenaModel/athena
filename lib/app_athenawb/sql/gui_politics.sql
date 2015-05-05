------------------------------------------------------------------------
-- TITLE:
--    gui_politics.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views, Politics area
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
-- POLITICS VIEWS

-- gui_supports: Support of one actor by another in neighborhoods.

CREATE TEMPORARY VIEW gui_supports AS
SELECT NA.n                                             AS n,
       N.link                                           AS nlink,
       N.longlink                                       AS nlonglink,
       NA.a                                             AS a,
       A.link                                           AS alink,
       A.longlink                                       AS alonglink,
       CASE WHEN NA.supports = NA.a   THEN 'SELF'
            WHEN NA.supports IS NULL  THEN 'NONE'
            ELSE NA.supports 
            END                                         AS supports,
       CASE WHEN NA.supports = NA.a   THEN 'SELF'
            WHEN NA.supports IS NULL  THEN 'NONE'
            ELSE link('/app/actor/' || NA.supports, NA.supports)
            END                                         AS supports_link
FROM supports_na AS NA
JOIN gui_nbhoods AS N ON (NA.n = N.n)
JOIN gui_actors  AS A ON (A.a = NA.a);


-- gui_agents: Data about agents for Detail Browsing
CREATE TEMPORARY VIEW gui_agents AS
SELECT agent_id                                         AS id,
       agent_id                                         AS agent_id,
       agent_type                                       AS agent_type,
       '/app/agent/' || agent_id                    AS url,
       agent_id                                         AS fancy,
       link('/app/agent/' || agent_id, agent_id)    AS link,
       link('/app/agent/' || agent_id, agent_id)    AS longlink
FROM agents;


-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------

