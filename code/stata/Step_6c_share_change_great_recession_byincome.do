/**********************************************************************;
* Project           : Heterogeneous Inflation
*
* Program name      : Step_11_share_change_great_recession.do
*
* Author            : Jacob Orchard 
*
* Date created      : 11/10/2020
*
* Purpose           : Share change in the great recession. Necessities vs. Luxuries
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* 3/4/21      J. Orchard          Update to allow for bootstrap standard errors of aggregate share
**********************************************************************/

clear all
version 16

*Directories


/*****************************************************************************
0. Program To Feed into Bootstrap
*****************************************************************************/

program mean_sn, rclass
	*Input: Cross-Sectional Consumption data (i.e. one quarter)
	*Output: Aggregate Necessity Share
	version 16
	preserve
		bsample 
		
		collapse   (mean) lsn [w=finlwt21], by(income_group)
		
		sum lsn
		local _asn = r(mean)
		return scalar asn = `_asn'
	restore
end


/*****************************************************************************
1. Imports Consumer expenditure data
******************************************************************************/


use $CEX/clean_mtbi.dta, clear


gen quarter = yq(year,qtrnum)
format quarter %tq
cap drop _merge

*Removes negative spending
replace cost = 0 if cost < 0

merge m:1 cuid quarter using $CEX/clean_fmli.dta, nogen keep(match) keepusing(finlwt21 total_spending income_group intmonth income fam_size age  no_earnr insample)
keep if insample
merge m:1 CPICategory using  $CEX/consumption_shares_income.dta, nogen


gen necessity =ratio_total > 1 & ratio_total != .
drop if ratio_total == .

*Removes housing expenditures and energy from total_spending
gen _housingcost = cost if CPICategory == "Housing"
egen housingcost = sum(_housingcost), by(cuid quarter)


gen total_spendingNH = total_spending - housingcost 

drop if CPICategory == "Housing" 


collapse (mean) finlwt21 income_group  total_spendingNH (sum) cost , by(necessity cuid quarter)


gen _nshare = cost/total_spendingNH if necessity == 1
egen nshare = max(_nshare), by(cuid quarter)

gen year = yofd(dofq(quarter))

collapse   (mean) nshare* [w=finlwt21], by(quarter income_group)

gen nshare_endR = nshare if quarter == yq(2009,2)
gen nshare_beginR = nshare if quarter == yq(2007,3)
gen nshare_endRec = nshare if quarter == yq(2012,4)
*gen nshare06 = nshare if year == 2006
*gen nshare10 = nshare if year == 2010

collapse (max) nshare*,by(income_group)


gen diffR = 100*(nshare_endR-nshare_beginR)
gen diffRec = 100*(nshare_endRec-nshare_endR)
*gen diff = nshare10-nshare06



/****************************************************************************
Bar Graph of Share Change by Income Group
****************************************************************************/




label var diffR "Necessity Share Change 2007Q2-2009Q3"
label var diffRec "Necessity Share Change 2007Q3-2012Q4"
label var income_group "Income Quintile"


	set scheme s2color

graph hbar diffR diffRec, over(income_group) stack legend(order(1 "2007Q3-2009Q2" 2 "2009Q2-2012Q4") ) ytitle(Percentage Point Change) bgcolor(white) graphregion(color(white)) 
graph export output/delta_sn_income.png, replace



/*
graph hbar diff, over(income_group) stack  ytitle(Percentage Point Change) bgcolor(white) graphregion(color(white)) 
graph export output/delta_yr_sn_income.png, replace


