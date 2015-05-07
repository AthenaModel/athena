------------------------------------------------------------------------
-- TITLE:
--    gui_ground.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views, Ground area
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
-- PERSONNEL VIEWS

-- gui_activity_nga: Activities by neighborhood and group 
CREATE TEMPORARY VIEW gui_activity_nga AS
SELECT n || ' ' || g || ' ' || a     AS id,
       n                             AS n,
       g                             AS g,
       a                             AS a,
       format('%6.4f',coverage)      AS coverage,
       CASE security_flag WHEN 1 THEN 'YES' ELSE 'NO' END AS security_flag,
       CASE can_do        WHEN 1 THEN 'YES' ELSE 'NO' END AS can_do,
       nominal                       AS nominal,
       effective                     AS effective
FROM activity_nga
WHERE nominal > 0
ORDER BY n,g,a;

-- gui_security: group security in neighborhoods, along with force 
-- statistics.
CREATE TEMPORARY VIEW gui_security AS
SELECT n || ' ' || g                      AS id,
       n                                  AS n,
       g                                  AS g,
       NG.personnel                       AS personnel,
       NG.security                        AS security,
       N.security                         AS nbsecurity,
       qsecurity('longname',NG.security)  AS symbol,
       actual_cf                          AS actual_cf,
       CASE WHEN actual_cf IS NULL 
            THEN 'n/a' 
            ELSE percent(actual_cf) END   AS pct_actual_cf,
       nominal_cf                         AS nominal_cf,
       CASE WHEN nominal_cf IS NULL 
            THEN 'n/a' 
            ELSE percent(nominal_cf) END  AS pct_nominal_cf,
       pct_force                          AS pct_force,
       pct_enemy                          AS pct_enemy,
       volatility                         AS volatility
FROM force_ng AS NG
JOIN force_n AS N USING (n)
LEFT OUTER JOIN force_civg USING (g)
WHERE personnel > 0
ORDER BY n, g;


-- gui_units: All active units
CREATE TEMPORARY VIEW gui_units AS
SELECT * FROM fmt_units;

-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------



