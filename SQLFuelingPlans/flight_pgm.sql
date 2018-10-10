--contains PGY, PGM, PG, CY, C
--based on specifications by HH

-- Runtime : 45m20.501s on Linus
-- Runtime : 16m11.295s on Janus

-- This script will create a flattened PGM representation of the views DB for launch (import into Dynasim, EBMA, DEMA etc.).
-- The output will be stored into preflight.20170407.

-- Spatial domain : GLOBAL.
-- Temporal domain : 1980 - 2030 but see below for data inclusion
-- Data inclusion : exactly as available in original sources except for li variables which have been extrapolated to 1980-2029.
-- Countries have been given the same territory (extrapolated) from 2014 to 2030.
-- Interpolation (linear) and extrapolation (linear) has been done for all variables containing li.
-- Extrapolation can produce absurd values (negative GCPs etc.). Use an update to resolve this if needed!

-- You may subfilter but *please do not use this table but make your own new copy with your changes*. It's also faster:
-- e.g.
--
-- CREATE TABLE flight_20160403_subsetxxxx AS
-- SELECT column1,column2... FROM flight_20160403 WHERE is_africa=1 AND year_id BETWEEN 1989 and 2015;

-- All column names are given explicitly as used below (no stars from stored data were used).
-- Some may be replaced with stars in the future depending on individual user needs

-- All joins are implicit inner joins since the relations are built around a complete universe
-- (i.e. all observations are included at all levels)
-- so an outer join on ids is the same thing as an inner joins

-- implicit joins (WHERE a.id = b.a_id) were used instead of (a INNER JOIN b ON (a.id=b.a_id)) for brevity and clarity.
-- there is one exception to data completeness:
-- pgy is [1980;2030]; everything else is [1980;2100]. Inner join will thus lead to [1980;2030]
-- so inner joins were used as we wanted [1980;2030] as domain.

-- order of operations :
-- JOIN pgy with pg ON pg.id with a CTE (in memory table) => pgy_pg (n pgy :: 1 pg)
-- JOIN pgy_pg with cy ON cy.id with another CTE => pgy_pg_cy (n pgy_pg :: 1 cy which is n pgy)
-- JOIN pgy_pg_cy with pgm on pgy.id to table => preflight.flight20170403 (n pgy_pg :: 1 cy)


-- Helper functions :
-- 1. public.country_id_to_gwcode(INT cy.country_id) -> INT gwno
-- Takes a Views country.id and returns its corresponding gwno. Needed since gwno not unique (border changes).
-- Reverse function not possible

-- 2. to_dummy(INT) -> INT
-- Converts a range to a dummy. Works like this:
-- 0 -> 0
-- [-inf;-1] AND [1;+inf] -> 1
-- null -> null

-- 3. to_dummy_threshold(INT $1, INT $2) -> INT
-- Converts a range to a dummy using the following scheme:
-- $1 in [-inf; $2) = 0
-- $i in [$2; +inf] = 1
-- null -> null

-- Quick postgres guide and Other postgres functions you may find useful for further processing:
-- column quotations are double apostrophe like so: "column_name".
-- However, we only use valid column names in Views so you don't need to quote.
-- fully valid column names are lower-case alphanumerics (az09) and dashes (_) with column names starting in an alpha (az).
-- string quotations are single quotes like so 'string value'
-- Operators are +-*/% and ^ for power
-- Logical operators are AND, OR, NOT, ILIKE, IN (Do not use LIKE; it behaves differently than in other SQLs and WRONGLY)
-- casts in postgres are done using the :: operator. To cast an int to a float do name_of_int_var::float
-- other functions:
-- ln(numeric) -> numeric : takes the natural (e) log of the value. Make sure 0 does not appear in the field.
-- log(numeric) -> numeric : takes the decimal log (10) of the value. Make sure 0 does not appear in the field.
-- round(numeric) -> numeric : performs rounding (5/4) to the nearest int. You will need to cast it explicitly to be stored as int though
-- random() -> numeric : generates a random float (0..1). Use multiplication, rounds and cast to ints to generate larger numbers.

-- Notes:
-- We store most values as double precision and bigints internally, including all ids.
-- The table is currently indexed on id with id as primary key. You may index it on whatever you want but DO NOT change the primary key.

DROP TABLE IF EXISTS preflight.flight_pgm;

CREATE TABLE preflight.flight_pgm AS
with pgy_pg AS
(
    SELECT
      pg.gid      AS pg_id,
      pgy.id      AS pgy_id,
      pgy.year_id AS year_id,
      pgy.country_year_id AS country_year_id,
      pg.col,
      pg.row,
      pg.latitude,
      pg.longitude,
      pg.cmr_max,
      pg.cmr_mean,
      pg.cmr_min,
      pg.cmr_sd,
      pg.diamsec_s,
      pg.diamprim_s,
      pg.gem_s,
      pg.goldplacer_s,
      pg.goldvein_s,
      pg.goldsurface_s,
      pg.petroleum_s,
      pg.maincrop,
      pg.growstart,
      pg.growend,
      pg.rainseas,
      pg.ttime_max,
      pg.ttime_mean,
      pg.ttime_min,
      pg.ttime_sd,
      pg.imr_max,
      pg.imr_mean,
      pg.imr_min,
      pg.imr_sd,
      pg.landarea,
      pg.agri_gc,
      pg.aquaveg_gc,
      pg.barren_gc,
      pg.forest_gc,
      pg.shrub_gc,
      pg.urban_gc,
      pg.water_gc,
      pg.mountains_mean,
      pg.in_africa,
      pg.dist_diaprim_s_wgs,
      pg.dist_diamsec_s_wgs,
      pg.dist_petroleum_s_wgs,
      pg.dist_goldsurface_s_wgs,
      pg.dist_goldplace_s_wgs,
      pg.dist_goldvein_s_wgs,
      pg.dist_gem_s_wgs,
      pg.petroleum_merged,
      pg.dist_petroleum_merged_wgs,
      pgy.bdist1,
      pgy.bdist2,
      pgy.bdist3,
      pgy.gwarea,
      pgy.gcp_li_ppp,
      pgy.gcp_li_mer,
      pgy.pop_li_gpw_sum,
      pgy.agri_ih,
      pgy.barren_ih,
      pgy.forest_ih,
      pgy.grass_ih,
      pgy.savanna_ih,
      pgy.pasture_ih,
      pgy.shrub_ih,
      pgy.urban_ih,
      pgy.water_ih,
      pgy.diamsec_y,
      pgy.diamprim_y,
      pgy.drug_y,
      pgy.gem_y,
      pgy.goldplacer_y,
      pgy.goldvein_y,
      pgy.goldsutface_y,
      pgy.petroleum_y,
      pgy.droughtcrop_speibase,
      pgy.droughtcrop_speigdm,
      pgy.droughtcrop_spi,
      pgy.droughthstart_speibase,
      pgy.droughthstart_speigdm,
      pgy.droughthstart_spi,
      pgy.droughthend_speibase,
      pgy.droughthend_speigdm,
      pgy.droughthend_spi,
      pgy.droughthyr_speibase,
      pgy.droughthyr_speigdm,
      pgy.droughthyr_spi,
      pgy.excluded,
      pgy.irrig_sum,
      pgy.irrig_li_sum,
      pgy.irrig_sd,
      pgy.irrig_li_sd,
      pgy.pop_hyd_li_sum,
      pgy.pop_hyd_sum,
      pgy.nlights_mean,
      pgy.nlights_min,
      pgy.nlights_max,
      pgy.nlights_sd,
      pgy.goldsurface_y,
      pgy.droughtstart_speibase,
      pgy.droughtstart_speigdm,
      pgy.droughtstart_spi,
      pgy.droughtend_speibase,
      pgy.droughtend_speigdm,
      pgy.droughtend_spi,
      pgy.droughtyr_spi,
      pgy.droughtyr_speibase,
      pgy.droughtyr_speigdm,
      pgy.capdist,
      pgy.urban_ih_li,
      pgy.bdist1_li,
      pgy.capdist_li,
      pgy.excluded_li,
      pgy.nlights_calib_mean,
      pgy.savanna_ih_li,
      pgy.agri_ih_li,
      pgy.barren_ih_li,
      pgy.forest_ih_li,
      pgy.pasture_ih_li,
      pgy.shrub_ih_li,
      pgy.water_ih_li,
      pgy.grass_ih_li,
      pgy.excluded_dummy_li,
      pgy.excluded_dummy,
      pgy.petroleum_merged_yearly
    FROM staging.priogrid AS pg, staging.priogrid_year AS pgy
    WHERE pg.gid = pgy.priogrid_gid
),
pgy_pg_cy AS
(
      SELECT
        pgy_pg.*,
        cy.fvp_timeindep,
        cy.fvp_timesincepreindepwar,
        cy.fvp_totshlowersec2024ssp2,
        cy.fvp_totshnoedu2024ssp2,
        cy.fvp_totshuppersec2024ssp2,
        cy.fvp_lnpop200,
        cy.fvp_timesinceregimechange,
        cy.fvp_grgdpcap_oilrent,
        cy.fvp_grgdpcap_nonoilrent,
        cy.fvp_oilunitrent,
        cy.fvp_oilprodcost,
        cy.fvp_oilprod,
        cy.fvp_bdbest_tot,
        cy.fvp_conflict,
        cy.fvp_dec60,
        cy.fvp_dec70,
        cy.fvp_dec80,
        cy.fvp_dec90,
        cy.fvp_durable,
        cy.fvp_auto,
        cy.fvp_demo,
        cy.fvp_democracy,
        cy.fvp_electoral,
        cy.fvp_liberal,
        cy.fvp_participatory,
        cy.fvp_regime3c,
        cy.fvp_semi,
        cy.fvp_grgdppercapita200,
        cy.fvp_grpop200,
        cy.fvp_indepyear,
        cy.fvp_lngdp200,
        cy.fvp_lngdpcap_nonoilrent,
        cy.fvp_lngdpcap_oilrent,
        cy.fvp_lngdppercapita200,
        cy.fvp_ltsc0,
        cy.fvp_ltsc1,
        cy.fvp_ltsc2,
        cy.fvp_nv_agr_totl_zs,
        cy.fvp_oilrent,
        cy.fvp_polity2,
        cy.fvp_population200,
        cy.fvp_prop_discriminated,
        cy.fvp_prop_dominant,
        cy.fvp_prop_excluded,
        cy.fvp_prop_irrelevant,
        cy.fvp_prop_powerless,
        cy.fvp_sp_dyn_imrt_in,
        cy.fvp_sp_dyn_tfrt_in,
        cy.ssp1_edu_sec_15_24_prop,
        cy.ssp1_fem_male_ratio_sec,
        cy.ssp1_non_workagepopprop,
        cy.ssp1_pop_iiasa,
        cy.ssp1_sec_edu_prop,
        cy.ssp2_edu_sec_15_24_prop,
        cy.ssp2_fem_male_ratio_sec,
        cy.ssp2_gdp_ppp_iiasa,
        cy.ssp2_gdp_ppp_oecd,
        cy.ssp2_gdppercap_iiasa,
        cy.ssp2_gdppercap_oecd,
        cy.ssp2_non_workagepopprop,
        cy.ssp2_pop_iiasa,
        cy.ssp2_sec_edu_prop,
        cy.ssp2_urban_share_iiasa,
        cy.ssp2_compl_prim_female_20_24,
        cy.ssp2_compl_prim_male_20_24,
        cy.ssp2_dep_ratio,
        cy.ssp2_f_lowsec_20_24,
        cy.ssp2_f_uppsec_20_24,
        cy.ssp2_incompl_prim_female_20_24,
        cy.ssp2_incompl_prim_male_20_24,
        cy.ssp2_m_lowsec_20_24,
        cy.ssp2_m_uppsec_20_24,
        cy.ssp2_non_workagepoptot,
        cy.ssp2_tot_f_pop,
        cy.ssp2_tot_lowsec_20_24,
        cy.ssp2_tot_m_pop,
        cy.ssp2_tot_noedu_20_24,
        cy.ssp2_tot_pop,
        cy.ssp2_tot_pop_15_19,
        cy.ssp2_tot_pop_20_24,
        cy.ssp2_tot_pop_above_65,
        cy.ssp2_tot_pop_below_15,
        cy.ssp2_tot_uppsec_20_24,
        cy.ssp2_workagepoptot,
        cy.ssp2_youth_bulges,
        cy.ssp2_mmnyrsschool2024,
        cy.ssp2_mnyrsschool2024,
        cy.ssp2_mshlowersec2024,
        cy.ssp2_mshnoedu2024,
        cy.ssp2_mshuppersec2024,
        cy.ssp2_ymhep,
        cy.ssp2_fmnyrsschool2024,
        cy.ssp2_fshlowersec2024,
        cy.ssp2_fshnoedu2024,
        cy.ssp2_fshuppersec2024,
        cy.ssp3_edu_sec_15_24_prop,
        cy.ssp3_fem_male_ratio_sec,
        cy.ssp3_non_workagepopprop,
        cy.ssp3_pop_iiasa,
        cy.ssp3_sec_edu_prop,
        cy.ssp4_edu_sec_15_24_prop,
        cy.ssp4_fem_male_ratio_sec,
        cy.ssp4_non_workagepopprop,
        cy.ssp4_pop_iiasa,
        cy.ssp4_sec_edu_prop,
        cy.ssp5_edu_sec_15_24_prop,
        cy.ssp5_fem_male_ratio_sec,
        cy.ssp5_non_workagepopprop,
        cy.ssp5_pop_iiasa,
        cy.ssp5_sec_edu_prop,
        cy.v2x_api,
        cy.v2x_civlib,
        cy.v2x_clphy,
        cy.v2x_clpol,
        cy.v2x_clpriv,
        cy.v2x_corr,
        cy.v2x_cspart,
        cy.v2x_delibdem,
        cy.v2x_edcomp_thick,
        cy.v2x_egal,
        cy.v2x_egaldem,
        cy.v2x_elecreg,
        cy.v2x_execorr,
        cy.v2x_feduni,
        cy.v2x_frassoc_thick,
        cy.v2x_freexp,
        cy.v2x_freexp_thick,
        cy.v2x_gencl,
        cy.v2x_gencs,
        cy.v2x_gender,
        cy.v2x_genpp,
        cy.v2x_hosinter,
        cy.v2x_jucon,
        cy.v2x_libdem,
        cy.v2x_liberal,
        cy.v2x_mpi,
        cy.v2x_partip,
        cy.v2x_partipdem,
        cy.v2x_polyarchy,
        cy.v2x_pubcorr,
        cy.v2x_suffr,
        cy.v2x_cl_rol,
        cy.v2x_cs_ccsi,
        cy.v2x_dd_dd,
        cy.v2x_dl_delib,
        cy.v2x_eg_eqdr,
        cy.v2x_eg_eqprotec,
        cy.v2x_el_elecparl,
        cy.v2x_el_elecpres,
        cy.v2x_el_frefair,
        cy.v2x_el_locelec,
        cy.v2x_el_regelec,
        cy.v2x_ex_elecreg,
        cy.v2x_lg_elecreg,
        cy.v2x_lg_legcon,
        cy.v2x_lg_leginter,
        cy.v2x_me_altinf,
        cy.v2x_ps_party,
        public.country_id_to_gwcode(cy.country_id :: INT) AS gwcode
      FROM pgy_pg, staging.country_year AS cy
      WHERE pgy_pg.country_year_id = cy.id
)
SELECT
  pgy_pg_cy.*,
  pgm.id,
  pgm.month_id,
  pgm.ged_best_sb,
  pgm.ged_best_ns,
  pgm.ged_best_os,
  pgm.ged_count_sb,
  pgm.ged_count_ns,
  pgm.ged_count_os,
  pgm.ged_best_sb_lag1,
  pgm.ged_best_ns_lag1,
  pgm.ged_best_os_lag1,
  pgm.ged_count_sb_lag1,
  pgm.ged_count_ns_lag1,
  pgm.ged_count_os_lag1,
  pgm.ged_best_sb_lag2,
  pgm.ged_best_ns_lag2,
  pgm.ged_best_os_lag2,
  pgm.ged_count_sb_lag2,
  pgm.ged_count_ns_lag2,
  pgm.ged_count_os_lag2,
  pgm.ged_best_sb_tlag1,
  pgm.ged_best_ns_tlag1,
  pgm.ged_best_os_tlag1,
  pgm.ged_count_sb_tlag1,
  pgm.ged_count_ns_tlag1,
  pgm.ged_count_os_tlag1,
  pgm.ged_best_sb_lag1_tlag1,
  pgm.ged_best_ns_lag1_tlag1,
  pgm.ged_best_os_lag1_tlag1,
  pgm.ged_count_sb_lag1_tlag1,
  pgm.ged_count_ns_lag1_tlag1,
  pgm.ged_count_os_lag1_tlag1,
  pgm.ged_best_sb_lag2_tlag1,
  pgm.ged_best_ns_lag2_tlag1,
  pgm.ged_best_os_lag2_tlag1,
  pgm.ged_count_sb_lag2_tlag1,
  pgm.ged_count_ns_lag2_tlag1,
  pgm.ged_count_os_lag2_tlag1,
  pgm.ged_best_sb_tlag2,
  pgm.ged_best_ns_tlag2,
  pgm.ged_best_os_tlag2,
  pgm.ged_count_sb_tlag2,
  pgm.ged_count_ns_tlag2,
  pgm.ged_count_os_tlag2,
  pgm.ged_best_sb_lag1_tlag2,
  pgm.ged_best_ns_lag1_tlag2,
  pgm.ged_best_os_lag1_tlag2,
  pgm.ged_count_sb_lag1_tlag2,
  pgm.ged_count_ns_lag1_tlag2,
  pgm.ged_count_os_lag1_tlag2,
  pgm.ged_best_sb_lag2_tlag2,
  pgm.ged_best_ns_lag2_tlag2,
  pgm.ged_best_os_lag2_tlag2,
  pgm.ged_count_sb_lag2_tlag2,
  pgm.ged_count_ns_lag2_tlag2,
  pgm.ged_count_os_lag2_tlag2,
  pgm.ged_best_sb_tlag3,
  pgm.ged_best_ns_tlag3,
  pgm.ged_best_os_tlag3,
  pgm.ged_count_sb_tlag3,
  pgm.ged_count_ns_tlag3,
  pgm.ged_count_os_tlag3,
  pgm.ged_best_sb_lag1_tlag3,
  pgm.ged_best_ns_lag1_tlag3,
  pgm.ged_best_os_lag1_tlag3,
  pgm.ged_count_sb_lag1_tlag3,
  pgm.ged_count_ns_lag1_tlag3,
  pgm.ged_count_os_lag1_tlag3,
  pgm.ged_best_sb_lag2_tlag3,
  pgm.ged_best_ns_lag2_tlag3,
  pgm.ged_best_os_lag2_tlag3,
  pgm.ged_count_sb_lag2_tlag3,
  pgm.ged_count_ns_lag2_tlag3,
  pgm.ged_count_os_lag2_tlag3,
  pgm.ged_best_sb_tlag4,
  pgm.ged_best_ns_tlag4,
  pgm.ged_best_os_tlag4,
  pgm.ged_count_sb_tlag4,
  pgm.ged_count_ns_tlag4,
  pgm.ged_count_os_tlag4,
  pgm.ged_best_sb_lag1_tlag4,
  pgm.ged_best_ns_lag1_tlag4,
  pgm.ged_best_os_lag1_tlag4,
  pgm.ged_count_sb_lag1_tlag4,
  pgm.ged_count_ns_lag1_tlag4,
  pgm.ged_count_os_lag1_tlag4,
  pgm.ged_best_sb_lag2_tlag4,
  pgm.ged_best_ns_lag2_tlag4,
  pgm.ged_best_os_lag2_tlag4,
  pgm.ged_count_sb_lag2_tlag4,
  pgm.ged_count_ns_lag2_tlag4,
  pgm.ged_count_os_lag2_tlag4,
  pgm.ged_best_sb_tlag5,
  pgm.ged_best_ns_tlag5,
  pgm.ged_best_os_tlag5,
  pgm.ged_count_sb_tlag5,
  pgm.ged_count_ns_tlag5,
  pgm.ged_count_os_tlag5,
  pgm.ged_best_sb_lag1_tlag5,
  pgm.ged_best_ns_lag1_tlag5,
  pgm.ged_best_os_lag1_tlag5,
  pgm.ged_count_sb_lag1_tlag5,
  pgm.ged_count_ns_lag1_tlag5,
  pgm.ged_count_os_lag1_tlag5,
  pgm.ged_best_sb_lag2_tlag5,
  pgm.ged_best_ns_lag2_tlag5,
  pgm.ged_best_os_lag2_tlag5,
  pgm.ged_count_sb_lag2_tlag5,
  pgm.ged_count_ns_lag2_tlag5,
  pgm.ged_count_os_lag2_tlag5,
  pgm.ged_best_sb_tlag6,
  pgm.ged_best_ns_tlag6,
  pgm.ged_best_os_tlag6,
  pgm.ged_count_sb_tlag6,
  pgm.ged_count_ns_tlag6,
  pgm.ged_count_os_tlag6,
  pgm.ged_best_sb_lag1_tlag6,
  pgm.ged_best_ns_lag1_tlag6,
  pgm.ged_best_os_lag1_tlag6,
  pgm.ged_count_sb_lag1_tlag6,
  pgm.ged_count_ns_lag1_tlag6,
  pgm.ged_count_os_lag1_tlag6,
  pgm.ged_best_sb_lag2_tlag6,
  pgm.ged_best_ns_lag2_tlag6,
  pgm.ged_best_os_lag2_tlag6,
  pgm.ged_count_sb_lag2_tlag6,
  pgm.ged_count_ns_lag2_tlag6,
  pgm.ged_count_os_lag2_tlag6,
  pgm.ged_best_sb_tlag7,
  pgm.ged_best_ns_tlag7,
  pgm.ged_best_os_tlag7,
  pgm.ged_count_sb_tlag7,
  pgm.ged_count_ns_tlag7,
  pgm.ged_count_os_tlag7,
  pgm.ged_best_sb_lag1_tlag7,
  pgm.ged_best_ns_lag1_tlag7,
  pgm.ged_best_os_lag1_tlag7,
  pgm.ged_count_sb_lag1_tlag7,
  pgm.ged_count_ns_lag1_tlag7,
  pgm.ged_count_os_lag1_tlag7,
  pgm.ged_best_sb_lag2_tlag7,
  pgm.ged_best_ns_lag2_tlag7,
  pgm.ged_best_os_lag2_tlag7,
  pgm.ged_count_sb_lag2_tlag7,
  pgm.ged_count_ns_lag2_tlag7,
  pgm.ged_count_os_lag2_tlag7,
  pgm.ged_best_sb_tlag8,
  pgm.ged_best_ns_tlag8,
  pgm.ged_best_os_tlag8,
  pgm.ged_count_sb_tlag8,
  pgm.ged_count_ns_tlag8,
  pgm.ged_count_os_tlag8,
  pgm.ged_best_sb_lag1_tlag8,
  pgm.ged_best_ns_lag1_tlag8,
  pgm.ged_best_os_lag1_tlag8,
  pgm.ged_count_sb_lag1_tlag8,
  pgm.ged_count_ns_lag1_tlag8,
  pgm.ged_count_os_lag1_tlag8,
  pgm.ged_best_sb_lag2_tlag8,
  pgm.ged_best_ns_lag2_tlag8,
  pgm.ged_best_os_lag2_tlag8,
  pgm.ged_count_sb_lag2_tlag8,
  pgm.ged_count_ns_lag2_tlag8,
  pgm.ged_count_os_lag2_tlag8,
  pgm.ged_best_sb_tlag9,
  pgm.ged_best_ns_tlag9,
  pgm.ged_best_os_tlag9,
  pgm.ged_count_sb_tlag9,
  pgm.ged_count_ns_tlag9,
  pgm.ged_count_os_tlag9,
  pgm.ged_best_sb_lag1_tlag9,
  pgm.ged_best_ns_lag1_tlag9,
  pgm.ged_best_os_lag1_tlag9,
  pgm.ged_count_sb_lag1_tlag9,
  pgm.ged_count_ns_lag1_tlag9,
  pgm.ged_count_os_lag1_tlag9,
  pgm.ged_best_sb_lag2_tlag9,
  pgm.ged_best_ns_lag2_tlag9,
  pgm.ged_best_os_lag2_tlag9,
  pgm.ged_count_sb_lag2_tlag9,
  pgm.ged_count_ns_lag2_tlag9,
  pgm.ged_count_os_lag2_tlag9,
  pgm.ged_best_sb_tlag10,
  pgm.ged_best_ns_tlag10,
  pgm.ged_best_os_tlag10,
  pgm.ged_count_sb_tlag10,
  pgm.ged_count_ns_tlag10,
  pgm.ged_count_os_tlag10,
  pgm.ged_best_sb_lag1_tlag10,
  pgm.ged_best_ns_lag1_tlag10,
  pgm.ged_best_os_lag1_tlag10,
  pgm.ged_count_sb_lag1_tlag10,
  pgm.ged_count_ns_lag1_tlag10,
  pgm.ged_count_os_lag1_tlag10,
  pgm.ged_best_sb_lag2_tlag10,
  pgm.ged_best_ns_lag2_tlag10,
  pgm.ged_best_os_lag2_tlag10,
  pgm.ged_count_sb_lag2_tlag10,
  pgm.ged_count_ns_lag2_tlag10,
  pgm.ged_count_os_lag2_tlag10,
  pgm.ged_best_sb_tlag11,
  pgm.ged_best_ns_tlag11,
  pgm.ged_best_os_tlag11,
  pgm.ged_count_sb_tlag11,
  pgm.ged_count_ns_tlag11,
  pgm.ged_count_os_tlag11,
  pgm.ged_best_sb_lag1_tlag11,
  pgm.ged_best_ns_lag1_tlag11,
  pgm.ged_best_os_lag1_tlag11,
  pgm.ged_count_sb_lag1_tlag11,
  pgm.ged_count_ns_lag1_tlag11,
  pgm.ged_count_os_lag1_tlag11,
  pgm.ged_best_sb_lag2_tlag11,
  pgm.ged_best_ns_lag2_tlag11,
  pgm.ged_best_os_lag2_tlag11,
  pgm.ged_count_sb_lag2_tlag11,
  pgm.ged_count_ns_lag2_tlag11,
  pgm.ged_count_os_lag2_tlag11,
  pgm.ged_best_sb_tlag12,
  pgm.ged_best_ns_tlag12,
  pgm.ged_best_os_tlag12,
  pgm.ged_count_sb_tlag12,
  pgm.ged_count_ns_tlag12,
  pgm.ged_count_os_tlag12,
  pgm.ged_best_sb_lag1_tlag12,
  pgm.ged_best_ns_lag1_tlag12,
  pgm.ged_best_os_lag1_tlag12,
  pgm.ged_count_sb_lag1_tlag12,
  pgm.ged_count_ns_lag1_tlag12,
  pgm.ged_count_os_lag1_tlag12,
  pgm.ged_best_sb_lag2_tlag12,
  pgm.ged_best_ns_lag2_tlag12,
  pgm.ged_best_os_lag2_tlag12,
  pgm.ged_count_sb_lag2_tlag12,
  pgm.ged_count_ns_lag2_tlag12,
  pgm.ged_count_os_lag2_tlag12,
  pgm.ged_months_since_last_sb,
  pgm.ged_months_since_last_ns,
  pgm.ged_months_since_last_os,
  pgm.ged_months_since_last_sb_lag1,
  pgm.ged_months_since_last_ns_lag1,
  pgm.ged_months_since_last_os_lag1,
  pgm.ged_months_since_last_sb_lag2,
  pgm.ged_months_since_last_ns_lag2,
  pgm.ged_months_since_last_os_lag2,
  pgm.dist_ged_sb_event,
  pgm.dist_ged_ns_event,
  pgm.dist_ged_os_event,
  pgm.dist_ged_sb_event_tlag1,
  pgm.dist_ged_ns_event_tlag1,
  pgm.dist_ged_os_event_tlag1,
  pgm.dist_ged_sb_event_tlag2,
  pgm.dist_ged_ns_event_tlag2,
  pgm.dist_ged_os_event_tlag2,
  pgm.dist_ged_sb_event_tlag3,
  pgm.dist_ged_ns_event_tlag3,
  pgm.dist_ged_os_event_tlag3,
  pgm.dist_ged_sb_event_tlag4,
  pgm.dist_ged_ns_event_tlag4,
  pgm.dist_ged_os_event_tlag4,
  pgm.dist_ged_sb_event_tlag5,
  pgm.dist_ged_ns_event_tlag5,
  pgm.dist_ged_os_event_tlag5,
  pgm.dist_ged_sb_event_tlag6,
  pgm.dist_ged_ns_event_tlag6,
  pgm.dist_ged_os_event_tlag6,
  pgm.dist_ged_sb_event_tlag7,
  pgm.dist_ged_ns_event_tlag7,
  pgm.dist_ged_os_event_tlag7,
  pgm.dist_ged_sb_event_tlag8,
  pgm.dist_ged_ns_event_tlag8,
  pgm.dist_ged_os_event_tlag8,
  pgm.dist_ged_sb_event_tlag9,
  pgm.dist_ged_ns_event_tlag9,
  pgm.dist_ged_os_event_tlag9,
  pgm.dist_ged_sb_event_tlag10,
  pgm.dist_ged_ns_event_tlag10,
  pgm.dist_ged_os_event_tlag10,
  pgm.dist_ged_sb_event_tlag11,
  pgm.dist_ged_ns_event_tlag11,
  pgm.dist_ged_os_event_tlag11,
  pgm.dist_ged_sb_event_tlag12,
  pgm.dist_ged_ns_event_tlag12,
  pgm.dist_ged_os_event_tlag12,
  public.to_dummy(acled_count_pr) as acled_dummy_pr,
  pgm.acled_count_pr,
  pgm.acled_count_pr_lag1,
  pgm.acled_count_pr_lag2,
  pgm.acled_count_pr_tlag1,
  pgm.acled_count_pr_tlag2,
  pgm.acled_count_pr_tlag3,
  pgm.acled_count_pr_tlag4,
  pgm.acled_count_pr_tlag5,
  pgm.acled_count_pr_tlag6,
  pgm.acled_count_pr_tlag7,
  pgm.acled_count_pr_tlag8,
  pgm.acled_count_pr_tlag9,
  pgm.acled_count_pr_tlag10,
  pgm.acled_count_pr_tlag11,
  pgm.acled_count_pr_tlag12,
  pgm.acled_count_pr_lag1_tlag1,
  pgm.acled_count_pr_lag1_tlag2,
  pgm.acled_count_pr_lag1_tlag3,
  pgm.acled_count_pr_lag1_tlag4,
  pgm.acled_count_pr_lag1_tlag5,
  pgm.acled_count_pr_lag1_tlag6,
  pgm.acled_count_pr_lag1_tlag7,
  pgm.acled_count_pr_lag1_tlag8,
  pgm.acled_count_pr_lag1_tlag9,
  pgm.acled_count_pr_lag1_tlag10,
  pgm.acled_count_pr_lag1_tlag11,
  pgm.acled_count_pr_lag1_tlag12,
  pgm.acled_count_pr_lag2_tlag1,
  pgm.acled_count_pr_lag2_tlag2,
  pgm.acled_count_pr_lag2_tlag3,
  pgm.acled_count_pr_lag2_tlag4,
  pgm.acled_count_pr_lag2_tlag5,
  pgm.acled_count_pr_lag2_tlag6,
  pgm.acled_count_pr_lag2_tlag7,
  pgm.acled_count_pr_lag2_tlag8,
  pgm.acled_count_pr_lag2_tlag9,
  pgm.acled_count_pr_lag2_tlag10,
  pgm.acled_count_pr_lag2_tlag11,
  pgm.acled_count_pr_lag2_tlag12,
  public.to_dummy_threshold(pgm.ged_best_sb, 1) AS ged_minor_sb,
  public.to_dummy_threshold(pgm.ged_best_sb, 5) AS ged_medium_sb,
  public.to_dummy_threshold(pgm.ged_best_sb, 25) AS ged_major_sb,
  public.to_dummy_threshold(pgm.ged_best_ns, 1) AS ged_minor_ns,
  public.to_dummy_threshold(pgm.ged_best_ns, 5) AS ged_medium_ns,
  public.to_dummy_threshold(pgm.ged_best_ns, 25) AS ged_major_ns,
  public.to_dummy_threshold(pgm.ged_best_os, 1) AS ged_minor_os,
  public.to_dummy_threshold(pgm.ged_best_os, 5) AS ged_medium_os,
  public.to_dummy_threshold(pgm.ged_best_os, 25) AS ged_major_os,
  public.to_dummy(ged_count_sb + ged_count_ns + ged_count_os) as ged_dummy,
  public.to_dummy(ged_count_sb) as ged_dummy_sb,
  public.to_dummy(ged_count_ns) as ged_dummy_ns,
  public.to_dummy(ged_count_os) as ged_dummy_os,
  public.to_dummy(ged_count_sb_lag1) as ged_dummy_sb_lag1,
  public.to_dummy(ged_count_ns_lag1) as ged_dummy_ns_lag1,
  public.to_dummy(ged_count_os_lag1) as ged_dummy_os_lag1,
  public.to_dummy(ged_count_sb_lag2) as ged_dummy_sb_lag2,
  public.to_dummy(ged_count_ns_lag2) as ged_dummy_ns_lag2,
  public.to_dummy(ged_count_os_lag2) as ged_dummy_os_lag2,
  public.to_dummy(ged_count_sb_tlag1) as ged_dummy_sb_tlag1,
  public.to_dummy(ged_count_ns_tlag1) as ged_dummy_ns_tlag1,
  public.to_dummy(ged_count_os_tlag1) as ged_dummy_os_tlag1,
  public.to_dummy(ged_count_sb_lag1_tlag1) as ged_dummy_sb_lag1_tlag1,
  public.to_dummy(ged_count_ns_lag1_tlag1) as ged_dummy_ns_lag1_tlag1,
  public.to_dummy(ged_count_os_lag1_tlag1) as ged_dummy_os_lag1_tlag1,
  public.to_dummy(ged_count_sb_lag2_tlag1) as ged_dummy_sb_lag2_tlag1,
  public.to_dummy(ged_count_ns_lag2_tlag1) as ged_dummy_ns_lag2_tlag1,
  public.to_dummy(ged_count_os_lag2_tlag1) as ged_dummy_os_lag2_tlag1,
  public.to_dummy(ged_count_sb_tlag2) as ged_dummy_sb_tlag2,
  public.to_dummy(ged_count_ns_tlag2) as ged_dummy_ns_tlag2,
  public.to_dummy(ged_count_os_tlag2) as ged_dummy_os_tlag2,
  public.to_dummy(ged_count_sb_lag1_tlag2) as ged_dummy_sb_lag1_tlag2,
  public.to_dummy(ged_count_ns_lag1_tlag2) as ged_dummy_ns_lag1_tlag2,
  public.to_dummy(ged_count_os_lag1_tlag2) as ged_dummy_os_lag1_tlag2,
  public.to_dummy(ged_count_sb_lag2_tlag2) as ged_dummy_sb_lag2_tlag2,
  public.to_dummy(ged_count_ns_lag2_tlag2) as ged_dummy_ns_lag2_tlag2,
  public.to_dummy(ged_count_os_lag2_tlag2) as ged_dummy_os_lag2_tlag2,
  public.to_dummy(ged_count_sb_tlag3) as ged_dummy_sb_tlag3,
  public.to_dummy(ged_count_ns_tlag3) as ged_dummy_ns_tlag3,
  public.to_dummy(ged_count_os_tlag3) as ged_dummy_os_tlag3,
  public.to_dummy(ged_count_sb_lag1_tlag3) as ged_dummy_sb_lag1_tlag3,
  public.to_dummy(ged_count_ns_lag1_tlag3) as ged_dummy_ns_lag1_tlag3,
  public.to_dummy(ged_count_os_lag1_tlag3) as ged_dummy_os_lag1_tlag3,
  public.to_dummy(ged_count_sb_lag2_tlag3) as ged_dummy_sb_lag2_tlag3,
  public.to_dummy(ged_count_ns_lag2_tlag3) as ged_dummy_ns_lag2_tlag3,
  public.to_dummy(ged_count_os_lag2_tlag3) as ged_dummy_os_lag2_tlag3,
  public.to_dummy(ged_count_sb_tlag4) as ged_dummy_sb_tlag4,
  public.to_dummy(ged_count_ns_tlag4) as ged_dummy_ns_tlag4,
  public.to_dummy(ged_count_os_tlag4) as ged_dummy_os_tlag4,
  public.to_dummy(ged_count_sb_lag1_tlag4) as ged_dummy_sb_lag1_tlag4,
  public.to_dummy(ged_count_ns_lag1_tlag4) as ged_dummy_ns_lag1_tlag4,
  public.to_dummy(ged_count_os_lag1_tlag4) as ged_dummy_os_lag1_tlag4,
  public.to_dummy(ged_count_sb_lag2_tlag4) as ged_dummy_sb_lag2_tlag4,
  public.to_dummy(ged_count_ns_lag2_tlag4) as ged_dummy_ns_lag2_tlag4,
  public.to_dummy(ged_count_os_lag2_tlag4) as ged_dummy_os_lag2_tlag4,
  public.to_dummy(ged_count_sb_tlag5) as ged_dummy_sb_tlag5,
  public.to_dummy(ged_count_ns_tlag5) as ged_dummy_ns_tlag5,
  public.to_dummy(ged_count_os_tlag5) as ged_dummy_os_tlag5,
  public.to_dummy(ged_count_sb_lag1_tlag5) as ged_dummy_sb_lag1_tlag5,
  public.to_dummy(ged_count_ns_lag1_tlag5) as ged_dummy_ns_lag1_tlag5,
  public.to_dummy(ged_count_os_lag1_tlag5) as ged_dummy_os_lag1_tlag5,
  public.to_dummy(ged_count_sb_lag2_tlag5) as ged_dummy_sb_lag2_tlag5,
  public.to_dummy(ged_count_ns_lag2_tlag5) as ged_dummy_ns_lag2_tlag5,
  public.to_dummy(ged_count_os_lag2_tlag5) as ged_dummy_os_lag2_tlag5,
  public.to_dummy(ged_count_sb_tlag6) as ged_dummy_sb_tlag6,
  public.to_dummy(ged_count_ns_tlag6) as ged_dummy_ns_tlag6,
  public.to_dummy(ged_count_os_tlag6) as ged_dummy_os_tlag6,
  public.to_dummy(ged_count_sb_lag1_tlag6) as ged_dummy_sb_lag1_tlag6,
  public.to_dummy(ged_count_ns_lag1_tlag6) as ged_dummy_ns_lag1_tlag6,
  public.to_dummy(ged_count_os_lag1_tlag6) as ged_dummy_os_lag1_tlag6,
  public.to_dummy(ged_count_sb_lag2_tlag6) as ged_dummy_sb_lag2_tlag6,
  public.to_dummy(ged_count_ns_lag2_tlag6) as ged_dummy_ns_lag2_tlag6,
  public.to_dummy(ged_count_os_lag2_tlag6) as ged_dummy_os_lag2_tlag6,
  public.to_dummy(ged_count_sb_tlag7) as ged_dummy_sb_tlag7,
  public.to_dummy(ged_count_ns_tlag7) as ged_dummy_ns_tlag7,
  public.to_dummy(ged_count_os_tlag7) as ged_dummy_os_tlag7,
  public.to_dummy(ged_count_sb_lag1_tlag7) as ged_dummy_sb_lag1_tlag7,
  public.to_dummy(ged_count_ns_lag1_tlag7) as ged_dummy_ns_lag1_tlag7,
  public.to_dummy(ged_count_os_lag1_tlag7) as ged_dummy_os_lag1_tlag7,
  public.to_dummy(ged_count_sb_lag2_tlag7) as ged_dummy_sb_lag2_tlag7,
  public.to_dummy(ged_count_ns_lag2_tlag7) as ged_dummy_ns_lag2_tlag7,
  public.to_dummy(ged_count_os_lag2_tlag7) as ged_dummy_os_lag2_tlag7,
  public.to_dummy(ged_count_sb_tlag8) as ged_dummy_sb_tlag8,
  public.to_dummy(ged_count_ns_tlag8) as ged_dummy_ns_tlag8,
  public.to_dummy(ged_count_os_tlag8) as ged_dummy_os_tlag8,
  public.to_dummy(ged_count_sb_lag1_tlag8) as ged_dummy_sb_lag1_tlag8,
  public.to_dummy(ged_count_ns_lag1_tlag8) as ged_dummy_ns_lag1_tlag8,
  public.to_dummy(ged_count_os_lag1_tlag8) as ged_dummy_os_lag1_tlag8,
  public.to_dummy(ged_count_sb_lag2_tlag8) as ged_dummy_sb_lag2_tlag8,
  public.to_dummy(ged_count_ns_lag2_tlag8) as ged_dummy_ns_lag2_tlag8,
  public.to_dummy(ged_count_os_lag2_tlag8) as ged_dummy_os_lag2_tlag8,
  public.to_dummy(ged_count_sb_tlag9) as ged_dummy_sb_tlag9,
  public.to_dummy(ged_count_ns_tlag9) as ged_dummy_ns_tlag9,
  public.to_dummy(ged_count_os_tlag9) as ged_dummy_os_tlag9,
  public.to_dummy(ged_count_sb_lag1_tlag9) as ged_dummy_sb_lag1_tlag9,
  public.to_dummy(ged_count_ns_lag1_tlag9) as ged_dummy_ns_lag1_tlag9,
  public.to_dummy(ged_count_os_lag1_tlag9) as ged_dummy_os_lag1_tlag9,
  public.to_dummy(ged_count_sb_lag2_tlag9) as ged_dummy_sb_lag2_tlag9,
  public.to_dummy(ged_count_ns_lag2_tlag9) as ged_dummy_ns_lag2_tlag9,
  public.to_dummy(ged_count_os_lag2_tlag9) as ged_dummy_os_lag2_tlag9,
  public.to_dummy(ged_count_sb_tlag10) as ged_dummy_sb_tlag10,
  public.to_dummy(ged_count_ns_tlag10) as ged_dummy_ns_tlag10,
  public.to_dummy(ged_count_os_tlag10) as ged_dummy_os_tlag10,
  public.to_dummy(ged_count_sb_lag1_tlag10) as ged_dummy_sb_lag1_tlag10,
  public.to_dummy(ged_count_ns_lag1_tlag10) as ged_dummy_ns_lag1_tlag10,
  public.to_dummy(ged_count_os_lag1_tlag10) as ged_dummy_os_lag1_tlag10,
  public.to_dummy(ged_count_sb_lag2_tlag10) as ged_dummy_sb_lag2_tlag10,
  public.to_dummy(ged_count_ns_lag2_tlag10) as ged_dummy_ns_lag2_tlag10,
  public.to_dummy(ged_count_os_lag2_tlag10) as ged_dummy_os_lag2_tlag10,
  public.to_dummy(ged_count_sb_tlag11) as ged_dummy_sb_tlag11,
  public.to_dummy(ged_count_ns_tlag11) as ged_dummy_ns_tlag11,
  public.to_dummy(ged_count_os_tlag11) as ged_dummy_os_tlag11,
  public.to_dummy(ged_count_sb_lag1_tlag11) as ged_dummy_sb_lag1_tlag11,
  public.to_dummy(ged_count_ns_lag1_tlag11) as ged_dummy_ns_lag1_tlag11,
  public.to_dummy(ged_count_os_lag1_tlag11) as ged_dummy_os_lag1_tlag11,
  public.to_dummy(ged_count_sb_lag2_tlag11) as ged_dummy_sb_lag2_tlag11,
  public.to_dummy(ged_count_ns_lag2_tlag11) as ged_dummy_ns_lag2_tlag11,
  public.to_dummy(ged_count_os_lag2_tlag11) as ged_dummy_os_lag2_tlag11,
  public.to_dummy(ged_count_sb_tlag12) as ged_dummy_sb_tlag12,
  public.to_dummy(ged_count_ns_tlag12) as ged_dummy_ns_tlag12,
  public.to_dummy(ged_count_os_tlag12) as ged_dummy_os_tlag12,
  public.to_dummy(ged_count_sb_lag1_tlag12) as ged_dummy_sb_lag1_tlag12,
  public.to_dummy(ged_count_ns_lag1_tlag12) as ged_dummy_ns_lag1_tlag12,
  public.to_dummy(ged_count_os_lag1_tlag12) as ged_dummy_os_lag1_tlag12,
  public.to_dummy(ged_count_sb_lag2_tlag12) as ged_dummy_sb_lag2_tlag12,
  public.to_dummy(ged_count_ns_lag2_tlag12) as ged_dummy_ns_lag2_tlag12,
  public.to_dummy(ged_count_os_lag2_tlag12) as ged_dummy_os_lag2_tlag12,
  COALESCE(CASE WHEN pgm.onset_months_sb >= 24 THEN 1 ELSE 0 END,0) as onset_sb_24,
  COALESCE(CASE WHEN pgm.onset_month_sb_lag1 >= 24 THEN 1 ELSE 0 END,0) as onset_sb_lag1_24,
  COALESCE(CASE WHEN pgm.onset_month_sb_lag2 >= 24 THEN 1 ELSE 0 END,0) as onset_sb_lag2_24,
  COALESCE(CASE WHEN pgm.onset_months_ns >= 24 THEN 1 ELSE 0 END,0) as onset_ns_24,
  COALESCE(CASE WHEN pgm.onset_month_ns_lag1 >= 24 THEN 1 ELSE 0 END,0) as onset_ns_lag1_24,
  COALESCE(CASE WHEN pgm.onset_month_ns_lag2 >= 24 THEN 1 ELSE 0 END,0) as onset_ns_lag2_24,
  COALESCE(CASE WHEN pgm.onset_months_os >= 24 THEN 1 ELSE 0 END,0) as onset_os_24,
  COALESCE(CASE WHEN pgm.onset_month_os_lag1 >= 24 THEN 1 ELSE 0 END,0) as onset_os_lag1_24,
  COALESCE(CASE WHEN pgm.onset_month_os_lag2 >= 24 THEN 1 ELSE 0 END,0) as onset_os_lag2_24,
  pgm.spei1_live as spei1,
  pgm.spei3_live as spei3,
  pgm.country_month_id
FROM pgy_pg_cy, staging.priogrid_month as pgm
WHERE pgy_pg_cy.pgy_id=pgm.priogrid_year_id;

ALTER TABLE preflight.flight_pgm ADD PRIMARY KEY(id);
CREATE INDEX flight_pgm_idx ON preflight.flight_pgm(id);