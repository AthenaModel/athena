------------------------------------------------------------------------
-- TITLE:
--    gui_econ.sql
--
-- AUTHOR:
--    Will Duquette
--
-- DESCRIPTION:
--    SQL Schema: Application-specific views, Economics area
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
-- ECONOMICS VIEWS

-- gui_econ_n: Neighborhood economic data.
CREATE TEMPORARY VIEW gui_econ_n AS
SELECT E.n                                          AS id,
       E.n                                          AS n,
       E.longname                                   AS longname,
       CASE E.local WHEN 1 THEN 'YES' ELSE 'NO' END AS local,
       format('%.2f',E.pcf)                         AS pcf,
       moneyfmt(E.cap0)                             AS cap0,
       moneyfmt(E.cap)                              AS cap,
       CAST(round(E.jobs0) AS INTEGER)              AS jobs0,
       CAST(round(E.jobs) AS INTEGER)               AS jobs,
       COALESCE(D.population,0)                     AS population,
       COALESCE(D.subsistence,0)                    AS subsistence,
       COALESCE(D.consumers,0)                      AS consumers,
       COALESCE(D.labor_force,0)                    AS labor_force,
       D.unemployed                                 AS unemployed,
       format('%.1f', D.ur)                         AS ur,
       format('%.1f', D.upc)                        AS upc,
       format('%.2f', D.uaf)                        AS uaf
FROM econ_n_view AS E
JOIN demog_n as D using (n)
JOIN nbhoods AS N using (n)
WHERE N.local;

-- gui_econ_g: Civilian group economic data
CREATE TEMPORARY VIEW gui_econ_g AS
SELECT * FROM fmt_civgroups 
JOIN nbhoods USING (n)
WHERE nbhoods.local;

-- gui_econ_income_a: Actor specific income from all sources
CREATE TEMPORARY VIEW gui_econ_income_a AS
SELECT a                                  AS id,
       a                                  AS a,
       moneyfmt(inc_goods)                AS income_goods,
       moneyfmt(inc_black_t)              AS income_black_t,
       moneyfmt(inc_black_nr)             AS income_black_nr,
       moneyfmt(inc_black_nr+inc_black_t) AS income_black_tot,
       moneyfmt(inc_pop)                  AS income_pop,
       moneyfmt(inc_world)                AS income_world,
       moneyfmt(inc_region)               AS income_graft
FROM income_a;

-- gui_econ_expense_a: Actor specific expenditures by sector
-- First row is current, second row is totals to date.
CREATE TEMPORARY VIEW gui_econ_expense_a AS
SELECT a                                AS id,
       a                                AS a,
       '<b>Current<\b>'                 AS lbl,
       moneyfmt(goods)                  AS exp_goods,
       moneyfmt(black)                  AS exp_black,
       moneyfmt(pop)                    AS exp_pop,
       moneyfmt(actor)                  AS exp_actor,
       moneyfmt(region)                 AS exp_region,
       moneyfmt(world)                  AS exp_world,
       moneyfmt(goods + black + pop + 
                actor + region + world) AS tot_exp
FROM expenditures
UNION
SELECT a                                AS id,
       a                                AS a,
       '<b>To Date<\b>'                 AS lbl,
       moneyfmt(tot_goods)              AS tot_goods,
       moneyfmt(tot_black)              AS tot_black,
       moneyfmt(tot_pop)                AS tot_pop,
       moneyfmt(tot_actor)              AS tot_actor,
       moneyfmt(tot_region)             AS tot_region,
       moneyfmt(tot_world)              AS tot_world,
       moneyfmt(tot_goods + tot_black + tot_pop + 
                tot_actor + tot_region + tot_world)
                                        AS grand_tot_exp
FROM expenditures;

-- gui_econ_exp_now_a: Actor specific expenditures by sector
-- at the current time.
CREATE TEMPORARY VIEW gui_econ_exp_now_a AS
SELECT a                                AS id,
       a                                AS a,
       moneyfmt(goods)                  AS exp_goods,
       moneyfmt(black)                  AS exp_black,
       moneyfmt(pop)                    AS exp_pop,
       moneyfmt(actor)                  AS exp_actor,
       moneyfmt(region)                 AS exp_region,
       moneyfmt(world)                  AS exp_world,
       moneyfmt(goods + black + pop + 
                actor + region + world) AS tot_exp
FROM expenditures;

-- gui_econ_exp_year_a: Annualized actor specific expenditures by
-- sector.
CREATE TEMPORARY VIEW gui_econ_exp_year_a AS
SELECT a                                AS id,
       a                                AS a,
       moneyfmt(goods  * 52.0)          AS exp_goods,
       moneyfmt(black  * 52.0)          AS exp_black,
       moneyfmt(pop    * 52.0)          AS exp_pop,
       moneyfmt(actor  * 52.0)          AS exp_actor,
       moneyfmt(region * 52.0)          AS exp_region,
       moneyfmt(world  * 52.0)          AS exp_world,
       moneyfmt((goods + black + pop + 
                actor + region + world) * 52.0) 
                                        AS tot_exp
FROM expenditures;

-- gui_econ_exp_tot_a: Total actor specific expenditures by sector
-- to date.
CREATE TEMPORARY VIEW gui_econ_exp_tot_a AS
SELECT a                                AS id,
       a                                AS a,
       moneyfmt(tot_goods)              AS exp_goods,
       moneyfmt(tot_black)              AS exp_black,
       moneyfmt(tot_pop)                AS exp_pop,
       moneyfmt(tot_actor)              AS exp_actor,
       moneyfmt(tot_region)             AS exp_region,
       moneyfmt(tot_world)              AS exp_world,
       moneyfmt(tot_goods + tot_black + tot_pop + 
                tot_actor + tot_region + tot_world) 
                                       AS tot_exp
FROM expenditures;

-----------------------------------------------------------------------
-- End of File
-----------------------------------------------------------------------

