/**********************************************************************;
* Project           : Heterogeneous Inflation
*
* Program name      : CEX_3_hhshares.do
*
* Author            : Jacob Orchard 
*
* Date created      : 10/19/2020
*
* Purpose           : Creates expenditure weights based on MTBI CEX files
*s
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* 
**********************************************************************/

clear all


/******************************************************************************
1. Merge MTBI files with household info
******************************************************************************/


use $CEX/clean_mtbi.dta, clear



gen quarter = yq(year,qtrnum)
format quarter %tq
cap drop _merge

*Removes negative spending
replace cost = 0 if cost < 0

egen total_spending_cat = sum(cost), by(cuid quarter)


merge m:1 cuid quarter using $CEX/clean_fmli.dta, nogen keep(match)  keepusing(finlwt21 total_spending income_group intmonth newid renteqvx rent insample)


*Total spending including imputed rental expenditure

replace renteqvx = 0 if renteqvx == .
gen _houseingexp = cost if CPICategory == "Housing"
egen housingexp =  max(_houseingexp), by(cuid quarter)
replace housingexp = 0 if housingexp == .
gen total_spending_wor = total_spending + 3*renteqvx + rent - housingexp


gen CPICode = CPICodenot

label data "Clean MTBI data with household weights and income group: CEX_3_hhshares.do 10.19.2020"


save $CEX/clean_mtbi_hhinfo.dta, replace




/******************************************************************************
2. Consumption Shares by income group
******************************************************************************/

use $CEX/clean_mtbi_hhinfo, clear

keep if insample
*Total Spending among included categories (Exclude Rent, Vehicle purchases, not labelled categories)
drop total_spending_cat

gen notincluded = CPICategory == "" | CPICategory == "Rent of Primary Residence" | CPICategory == "Owner's equivalent rent of residences" | CPICategory == "Housing"

egen total_spending_cat = sum(cost) if notincluded == 0, by(quarter cuid) 

gen cshare1 = cost/total_spending if CPICategory != "" & total_spending > 0 
replace cshare1 = . if cshare1 > 1

gen cshare2 = cost/total_spending_cat

gen cshare3 = cost/total_spending_wor if CPICategory != "" & total_spending > 0 
replace cshare3 = . if cshare3 > 1

label var cshare1 "Consumption Share: Cost divided by FMLI spending"
label var cshare2 "Consumption Share: Cost divided by MTBI included categories"
label var cshare3 "Consumption Share: Cost divided by FMLI spending plus imputed rent"

replace rent = 0 if rent == . & year > 1994
gen rentshare = rent/total_spending_wor
gen ownshare = 3*renteqvx/total_spending_wor if year > 1994



save $CEX/exp_shares_hh.dta, replace



*Expands data so each household has an observation for each CPI group in each year
keep if CPICategory != ""
*keep if notincluded == 0

egen CPIgroup = group(CPICategory)
labmask CPIgroup, value(CPICategory)


preserve 
tempfile CPIname

collapse (mean) cost, by(CPIgroup CPICategory CPICode CPICodenot CPICodeseas)

drop cost

save $CEX/cpi_categories.dta, replace
restore


preserve
tempfile allcat

keep quarter cuid cost CPIgroup finlwt21 income_group

reshape wide cost, i(quarter cuid finlwt21 income_group) j(CPIgroup)

reshape long cost, i(quarter cuid finlwt21 income_group) j(CPIgroup)

replace cost = 0 if cost == .
save `allcat'
restore

merge 1:1 quarter cuid CPIgroup using `allcat'

replace cshare1 = 0 if cost == 0
replace cshare2 = 0 if cost == 0
replace cshare3 = 0 if cost == 0

egen _ownshare = max(ownshare), by(quarter cuid)
egen _rentshare = max(rentshare), by(quarter cuid)
 
*Average Shares by Income-group Quarter


collapse (mean) cshare* ownshare = _ownshare rentshare =_rentshare [w=finlwt21], by(quarter income_group CPIgroup) fast



merge m:1 CPIgroup using $CEX/cpi_categories

save $CEX/consumption_shares_quarter.dta, replace //This data file is used in creating low-income/high-income CPIs for appendix figure



use $CEX/consumption_shares_quarter, clear
drop if cshare1 == 0


*Pools all data together

collapse (mean) cshare*, by(income_group CPIgroup)




rename cshare1 cshare_total
rename cshare2 cshare_included

merge m:1 CPIgroup using $CEX/cpi_categories

drop _merge
reshape wide cshare*, i(CPICategory CPICode CPIgroup) j(income_group)


gen ratio_total = cshare_total1/cshare_total5

gen ratio_included = cshare_included1/cshare_included5


save $CEX/consumption_shares_income.dta, replace


gsort -ratio_total

gen rank_total = _n

gsort -ratio_included

gen rank_included = _n


preserve

keep CPICategory cshare_total* ratio_total 


gsort -ratio_total


order CPICategory cshare_total* ratio_total

forval i = 1/5{
	
	replace cshare_total`i' = 100*cshare_total`i'
	
}

export excel using output/revealed_engel.xls, replace

restore

*Amount of spending represented
preserve
collapse (sum) cshare*
sum cshare_total*
restore




/******************************************************************************
3. Aggregate Consumption Share
******************************************************************************/

use $CEX/clean_mtbi_hhinfo, clear

merge m:1 CPICategory using $CEX/CEX_durable.dta, nogen



egen CPIgroup = group(CPICategory)



*One total spending obs. per household so as to not double sum
egen onehh = tag(cuid quarter)

gen total_spending1 = total_spending if onehh ==1
gen total_spending_nd = cost if durable == 0 & oil == 0 & transportation ==0

*Housing Share
preserve
gen house = CPICategory == "Housing"
collapse (sum) cost [w=finlwt21], by(house quarter)
reshape wide cost, i(quarter) j(house)
gen house_share = cost0/cost1
sum house_share if quarter == yq(2019,1)
restore

preserve 
tempfile aggspend
collapse (mean) avspend = total_spending1 (sum) total_spending1 total_spending_nd  [w=finlwt21], by(quarter)
label variable avspend "Average Household Spending"
label variable total_spending1 "Sum of Household Spending"
save `aggspend'
restore


collapse (mean) avcost = cost  (sum) cost [w=finlwt21], by(CPICategory quarter)

merge m:1 quarter using `aggspend'

gen agg_share = cost/total_spending1
gen agg_share2 = avcost/avspend
compare agg_share agg_share2 

gen agg_share_nd = cost/total_spending_nd 




label data "Aggregate Spending Shares"

merge m:1 CPICategory using $CEX/consumption_shares_income.dta, nogen

drop if CPICategory == ""
drop if CPIgroup == .

keep CPICategory quarter agg_share avspend total_spending1 agg_share_nd cost


save $CEX/aggregate_shares.dta, replace





/******************************************************************************
4. Table 1
******************************************************************************/



use $CEX/aggregate_shares.dta, clear


collapse (mean) agg_share, by(CPICategory)

merge 1:1 CPICategory using $CEX/consumption_shares_income.dta, nogen

gsort ratio_total
export excel CPICategory ratio_total agg_share using output/luxury_list.xls, replace

gsort -ratio_total
export excel CPICategory ratio_total agg_share using output/necessity_list.xls, replace



/******************************************************************************
5. Table 2
******************************************************************************/

merge m:1 CPICategory using $CEX/CEX_durable.dta, nogen
gen energy = oil | transportation
gen necessity = ratio_total >1 
replace necessity = . if ratio_total == .
drop  if  CPICategory == "Housing"

egen sumtotal = sum(agg_share),by(necessity)



local list `"durable" "service" "energy"'

foreach x in "`list'" {
	
	egen `x'total = sum(agg_share),by(necessity `x')
	gen `x'_share = `x'total/sumtotal
	
	bys necessity: sum `x'_share if `x'
	bys necessity: tab `x'
	
}

tab necessity
bys necessity: sum agg_share



