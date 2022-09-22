/******************************************************************************

Master do file for "Competing for Necessities"

Jacob Orchard:
Project Dates: 2019-Current



******************************************************************************/


*Set Fredkey
cap set fredkey //Add own fredkey here

*User Programs
cap ssc install binscatter
cap ssc install reghdfe
cap ssc install palettes
cap ssc install colrspace
cap ssc install egenmore
cap ssc install _gwtmean

global rawdata "raw_data"
global deriveddata "derived_data"
global CEX "derived_data/CEX" 
global CPI "derived_data/CPI"
global temp "derived_data/temp"
global stata "code/stata"
global output "output"


cap mkdir $deriveddata
cap mkdir $deriveddata/temp
cap mkdir $deriveddata/CEX
cap mkdir $deriveddata/CPI
cap mkdir output

/*******************************************************************************
Do File List
*******************************************************************************/
***Data Prep***
do $stata/Step_0_CEX_BLSdownload
do $stata/Step_1_CEX_hhinfo
do $stata/Step_2_CEX_hhspend
do $stata/Step_3_CEX_exp_shares
 do $stata/Step_4_CPI_import_prices

***Motivating Figures***
do $stata/Step_5_income_level_cpi
do $stata/Step_6a_create_pn_timeseries
do $stata/Step_6b_share_change_great_recession
do $stata/Step_6c_share_change_great_recession_byincome

***Regressions***
do $stata/Step_7_create_regressionvars.do
do $stata/Step_8_reg_prices_unemployment
do $stata/Step_9_reg_shares_unemployment
do $stata/Step_10_reg_exp_unemployment


*IRF Figures
do $stata/Monetary_Elasticity_IRF_monthly

*Model Estimation
do $stata/Step_11_calibratemodel
do $stata/Step_12_timeseries_data_for_model

cd code/AIDS_NK_PL1
!matlab -nodesktop -r "run 'main_twosector_alids_baseline'"
cd "../../"

***Robustness Checks***
do $stata/Robust_1_CEX_exp_shares_bydecade
do $stata/Robust_2_Compare_necessity_overtime
do $stata/Robust_3_create_pn_timeseries_bydecade

cd code/AIDS_NK_PL1
!matlab -nodesktop -r "run 'main_twosector_alids_all_calibrations_onegraph'"
cd "../../"