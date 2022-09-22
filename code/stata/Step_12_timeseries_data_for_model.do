/**********************************************************************;
* Project           : Competing for necessities
*
* Program name      : calibrate_twosector.do
*
* Author            : Jacob Orchard 
*
* Date created      : 1/28/2021
*
* Purpose           : Calibrates expenditure variables
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* 
**********************************************************************/

clear all



/*****************************************************************************
1. Pull in data and create quarterly average necessity share and rep exp.
*****************************************************************************/

use $CEX/quarterly_calibration_data.dta, replace


collapse (mean) pn* pce Xr theil agg_n agg_n_ne rlspend cpi total_spendingNH, by(quarter)

rename agg_n_ne SN

/******************************************************************************
2. TSFILTERED DATA
*******************************************************************************/


tsset quarter
gen quarternum = quarter(dofq(quarter))
*Converts nominal values to 2007Q1 dollars

gen _cpi2007 = cpi if quarter == yq(2007,1)
egen cpi2007 = max(_cpi2007)
replace cpi = cpi/cpi2007

foreach var in Xr total_spending pce{
	
	replace `var' = `var'/cpi
	
	
}


gen lXr= log(Xr)
gen lpce = log(pce)
gen lsn = log(agg_n)
gen lX_cex = log(total_spending)
gen smoothlsn = (lsn + l.lsn + l2.lsn)/3
*Seasonally smooth and filters data

foreach var in lpce lXr lX_cex lsn smoothlsn agg_n SN{
	
	reg `var' i.quarternum 
	predict `var'_sa, resid
	replace `var'_sa = `var'_sa + _b[_cons] 
	forval j = 2/4{

	replace `var'_sa = _b[`j'.quarternum]/4 + `var'_sa
	}
	
	reg `var'_sa l(12/15).`var'_sa //Filters using method in Hamilton 2017
	predict `var'_filter, resid
	

	
}




*Constructs data to export to MATLAB

foreach var in agg_n_filter lXr_filter lpce_filter lsn_filter lX_cex_filter lX_cex_sa lsn_sa lpce_sa lXr_sa pn1997_sa pn1987_sa pn1997_filter pn1987_filter smoothlsn_filter  SN_filter{
gen _`var'20073 = `var' if quarter ==yq(2007,3)
egen `var'20073 = max(_`var'20073)
gen `var'_diff = `var' - `var'20073
}

*Different types of spending measures differenced

*Filtered
tsline  lXr_filter_diff lpce_filter_diff lX_cex_filter_diff if quarter > yq(2007,2) & quarter < yq(2013,1)

*Seasonally adjusted only
tsline  lXr_sa_diff lpce_sa_diff lX_cex_sa_diff if quarter > yq(2007,2) & quarter < yq(2013,1)

*Together now
tsline  lsn_filter_diff   lpce_filter_diff pn1997_filter_diff agg_n_filter_diff if quarter > yq(2007,2) & quarter < yq(2013,1)

keep if quarter > yq(1993,4)


*keep if quarter > yq(2000,1) & quarter <yq(2019,4)

keep quarter smoothlsn_filter_diff lsn_filter_diff  lpce_filter_diff pn1997_filter_diff agg_n_filter_diff pn1987_filter_diff SN_filter_diff lXr_filter_diff
export delimited $CEX/calibrate_twosector, replace



/*******************************************************************************
3. Long (1970-2020) series
*******************************************************************************/


freduse PCE, clear
gen quarter = qofd(daten)
collapse PCE, by(quarter)

merge 1:1 quarter using $CPI/pnseries.dta, gen(mpce)



gen lpce = log(pce)

foreach var in lpce {
	
	reg `var' i.quarternum 
	predict `var'_sa, resid
	replace `var'_sa = `var'_sa + _b[_cons] 
	forval j = 2/4{

	replace `var'_sa = _b[`j'.quarternum]/4 + `var'_sa
	}
	
	reg `var'_sa l(12/15).`var'_sa //Filters using method in Hamilton 2017
	predict `var'_filter, resid
	

	
}

*For matlab export
foreach var in lpce_filter  pn1967_filter {
gen _`var'20073 = `var' if quarter ==yq(2007,3)
egen `var'20073 = max(_`var'20073)
gen `var'_diff = `var' - `var'20073
}

format quarter %tq
drop if pn1967_filter_diff == .

keep quarter  lpce_filter_diff pn1967_filter_diff 
export delimited $CEX/calibrate_twosector_long, replace

