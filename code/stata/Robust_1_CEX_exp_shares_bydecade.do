/**********************************************************************;
* Project           : Competing for Necessities
*
* Program name      : Robust_1_CEX_exp_shares_bydecade.do
*
* Author            : Jacob Orchard 
*
* Date created      : 6/28/2021
*
* Purpose           : Creates expenditure weights based on MTBI CEX files. Isolates by decade
*s
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* 
**********************************************************************/

clear all


/******************************************************************************
1. Isolates by decade
*****************************************************************************/
local decadelist `"1990" "2000" "2010"'

foreach decade in "`decadelist'"{



/******************************************************************************
2. Consumption Shares by income group
******************************************************************************/

use $CEX/clean_mtbi_hhinfo, clear
di `decade'
drop if income_group == .
keep if year >= `decade' & year < `decade' + 10

*Total Spending among included categories (Exclude Rent, Vehicle purchases, not labelled categories)
drop total_spending_cat

gen notincluded = CPICategory == "" | CPICategory == "Rent of Primary Residence" | CPICategory == "Owner's equivalent rent of residences" | CPICategory == "Housing"

egen total_spending_cat = sum(cost) if notincluded == 0, by(quarter cuid) 

gen cshare1 = cost/total_spending if CPICategory != "" & total_spending > 0 
replace cshare1 = . if cshare1 > 1

gen cshare2 = cost/total_spending_cat

label var cshare1 "Consumption Share: Cost divided by FMLI spending"
label var cshare2 "Consumption Share: Cost divided by MTBI included categories"

save $CEX/exp_shares_hh`decade'.dta, replace



*Expands data so each household has an observation for each CPI group in each year
keep if CPICategory != ""
*keep if notincluded == 0

egen CPIgroup = group(CPICategory)

preserve 
tempfile CPIname

collapse (mean) cost, by(CPIgroup CPICategory CPICode CPICodenot CPICodeseas)

drop cost

save $CEX/cpi_categories`decade'.dta, replace
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

 
*Average Shares by Income-group Quarter


collapse (mean) cshare1 cshare2 [w=finlwt21], by(quarter income_group CPIgroup) fast



merge m:1 CPIgroup using $CEX/cpi_categories`decade'

save $temp/consumption_shares_quarter`decade'.dta, replace


use $temp/consumption_shares_quarter`decade', clear
drop if cshare1 == 0


*Pools all data together

collapse (mean) cshare*, by(income_group CPIgroup)




rename cshare1 cshare_total
rename cshare2 cshare_included

merge m:1 CPIgroup using $CEX/cpi_categories`decade'

drop _merge
reshape wide cshare*, i(CPICategory CPICode CPIgroup) j(income_group)


gen ratio_total = cshare_total5/cshare_total1

gen ratio_included = cshare_included5/cshare_included1


save $CEX/consumption_shares_income`decade'.dta, replace


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

export excel using output/revealed_engel`decade'.xls, replace

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
keep if year >= `decade' & year < `decade' + 10

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

merge m:1 CPICategory using $CEX/consumption_shares_income`decade'.dta, nogen

drop if CPICategory == ""
drop if CPIgroup == .

keep CPICategory quarter agg_share avspend total_spending1 agg_share_nd cost


save $CEX/aggregate_shares`decade'.dta, replace





/******************************************************************************
4. Table 1 by decade
******************************************************************************/



use $CEX/aggregate_shares`decade'.dta, clear


collapse (mean) agg_share, by(CPICategory)

merge 1:1 CPICategory using $CEX/consumption_shares_income`decade'.dta, nogen

gsort -ratio_total
export excel CPICategory ratio_total agg_share using output/luxury_list`decade'.xls, replace

sort ratio_total
export excel CPICategory ratio_total agg_share using output/necessity_list`decade'.xls, replace

}
