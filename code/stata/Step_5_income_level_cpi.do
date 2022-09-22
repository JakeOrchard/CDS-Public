/**********************************************************************;
* Project           : Cyclical Demand Shifts
*
* Program name      : Step_5_income_level_cpi.do
*
* Author            : Jacob Orchard 
*
* Date created      : 8/18/2021
*
* Purpose           : Creates Income level CPIs using 2005-06 expenditures to create weights
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYyqMDD format) 
* 
**********************************************************************/


clear all

/******************************************************************************
1. Create Weights by income group 2005-06
******************************************************************************/


use $CEX/consumption_shares_quarter.dta, clear


keep if quarter < yq(2007,1) & quarter > yq(2004,4)
drop if CPICategory == "Housing" //Housing included in ownshare and rentshare 

collapse (mean) cshare3 ownshare rentshare, by(CPICategory income_group)

rename cshare3 weight_all

merge m:1 CPICategory using $CEX/CEX_durable.dta, keep(match) nogen

gen weight_core = weight if oil == 0 & transportation == 0 & CPICategory != "Food at Home" & CPICategory != "Food Away from Home" & CPICategory != "Food at Elementary and Secondary Schools"

foreach weight in weight_all weight_core{
     
egen _total_weight = sum(`weight'), by(income_group)
gen total_weight = _total_weight + ownshare + rentshare //missing some categories weights add to around 97% of CEX Consumption spending
replace `weight' = `weight'/total_weight
gen OWN`weight' = ownshare/total_weight
gen RENT`weight' = rentshare/total_weight 

drop  *total_weight

}


drop rentshare ownshare

reshape wide weight* OWN* RENT*, i(CPICategory) j(income_group)

tempfile weights 
save `weights'

/******************************************************************************
2. Pull in prices
******************************************************************************/


preserve  //Own and rental prices from fred
freduse CUSR0000SEHA  CUSR0000SEHC, clear

gen quarter = qofd(daten)

rename CUSR0000SEHA cpi_rent
rename CUSR0000SEHC cpi_ownrent

drop daten date

collapse (mean) cpi_rent cpi_ownrent, by(quarter)
tempfile fred
save `fred'
restore

use $CPI/sector_prices.dta, clear //other prices from step_4
gen quarter = qofd(dofm(month))
collapse (mean) value, by(CPICategory quarter)

merge m:1 quarter using `fred', keep(match) nogen

merge m:1 CPICategory using `weights', keep(match) nogen

*normalize prices so price index == 100 in 2007Q1
foreach var in value cpi_rent cpi_ownrent{
    
	gen _`var'2007 = `var' if quarter ==yq(2007,1)
	egen `var'2007 = max(_`var'2007),by(CPICategory)
	replace `var' = 100*`var'/`var'2007
	drop `var'2007 _`var'2007
	
	
}

*Make sure weights add to one in each period
forval i = 1/5{
   foreach weight in weight_all weight_core{ 
		egen sumshare = sum(`weight'`i'), by(quarter)
		gen tshare = sumshare + OWN`weight'`i'+RENT`weight'`i'
		
		replace `weight'`i' = `weight'`i'/tshare
		replace OWN`weight'`i' = OWN`weight'`i'/tshare
		replace RENT`weight'`i' =  RENT`weight'`i'/tshare
		drop tshare sumshare
   }
	
}


/******************************************************************************
3. Construct CPI's by income group (2005-2006 weights)
******************************************************************************/


forval i = 1/5{
    foreach ver in all core{
    
	gen laspeyres_`ver'`i' = weight_`ver'`i'*value
	gen l`i'_`ver'rent = RENTweight_`ver'`i'*cpi_rent if CPICategory == "Admissions" //rest should be missing so as not to double count
	//Could use any CPICategory here
	gen l`i'_`ver'own = OWNweight_`ver'`i'*cpi_ownrent if CPICategory == "Admissions"
	}
	
}



collapse (sum) laspeyres* (max) *rent *own, by(quarter)

tsset quarter


forval i = 1/5{
    
	gen cpi`i'_all = laspeyres_all`i' + l`i'_allrent + l`i'_allown
	gen cpi`i'_core = laspeyres_core`i' + l`i'_corerent + l`i'_coreown

}

keep cpi* quarter
drop cpi_rent cpi_own

preserve // pull in CPI-U from FRED
freduse CPIAUCSL CPILFESL, clear
gen quarter = qofd(daten)
rename CPIAUCSL cpiu
rename CPILFESL cpi_core

collapse (mean) cpiu cpi_core, by(quarter)


*normalize prices so price index == 100 in 2007Q1 or 2007Q3 (for model comparison)
foreach var in cpiu cpi_core{
    
	gen _`var'2007 = `var' if quarter ==yq(2007,1)
	egen `var'2007 = max(_`var'2007)
	replace `var' = 100*`var'/`var'2007
	drop `var'2007 _`var'2007
	
	
}


keep quarter cpiu cpi_core
tempfile cpi
save `cpi'
restore


merge 1:1 quarter using `cpi'

format quarter %tq

sort quarter

*****************************************************************************
*Create Inflation Rates
****************************************************************************

foreach var in cpi1_all cpi5_all cpi1_core cpi5_core{
    
	gen `var'_pi = 100*(`var'- l4.`var')/l4.`var'
	
	
}
gen piall_diff = cpi1_all_pi - cpi5_all_pi
gen picore_diff = cpi1_core_pi - cpi5_core_pi



/******************************************************************************
4. EXPORT GRAPHS
******************************************************************************/


set scheme s1color

******************************************************************************
* ALL ITEMS CPI
***************************************************************************


summarize cpi1_all if quarter > yq(2006,4) & quarter<yq(2013,1)
local max = r(max)
sum cpiu if quarter > yq(2006,4) & quarter<yq(2013,1)
local min = r(min)


twoway function y=`max',range(191 197) recast(area) color(gs12) base(`min') || ///  
(tsline cpi1_all if quarter > yq(2006,4) & quarter<yq(2013,1),  lcolor(red) ) || ///
(tsline cpi3_all if quarter > yq(2006,4) & quarter<yq(2013,1),  lcolor(blue) lpattern("-")) || ///
(tsline cpi5_all if quarter > yq(2006,4) & quarter<yq(2013,1),  lcolor(green)) || ///
   ,         ///
legend(label(2 "CPI Low-Income")  label(3 "CPI Mid-Income") label(4 "CPI High-Income")  cols(2) rows(2) order( 2 3 4  )  ) ///                                        ///                                     ///
xtitle("") ytitle("CPI")          ///
tlabel(188(4)208, format(%tqCCYY))

graph export "output/income_level_cpi.png", replace


*Inflation Difference 2000-2020

summarize piall_diff if quarter > yq(2000,1) & quarter<yq(2020,4)
local max = r(max)
local min = r(min)

twoway function y=`max',range(164 167) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(191 197) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(240 241) recast(area) color(gs12) base(`min') || ///
(tsline piall_diff if quarter > yq(2000,1) ,  lcolor(black) ) ||, ///
xtitle("") ytitle("Low- v. High-Income Inflation")   legend(off)       ///
tlabel(160(8)240, format(%tqCCYY))

graph export "output/income_level_inflation_all.png", replace


*******************************************************************************
* CORE CPI
******************************************************************************

summarize cpi1_core if quarter > yq(2006,4) & quarter<yq(2013,1)
local max = r(max)
sum cpi5_core if quarter > yq(2006,4) & quarter<yq(2013,1)
local min = r(min)

twoway function y=115,range(191 197) recast(area) color(gs12) base(`min') || ///  
(tsline cpi1_core if quarter > yq(2006,4) & quarter<yq(2013,1),  lcolor(red) ) || ///
(tsline cpi3_core if quarter > yq(2006,4) & quarter<yq(2013,1),  lcolor(blue) lpattern("-")) || ///
(tsline cpi5_core if quarter > yq(2006,4) & quarter<yq(2013,1),  lcolor(green)) || ///
    ,         ///
legend(label(2 "Core CPI Low-Income")  label(3 "Core CPI Mid-Income") label(4 "Core CPI High-Income")  cols(2) rows(2) order( 2 3 4  )  ) ///                                        ///                                     ///
xtitle("") ytitle("CPI Less Food and Energy")         ///
tlabel(188(4)208, format(%tqCCYY))

graph export "output/income_level_cpi_core.png", replace


*Core Inflation Difference 2000-2020

summarize picore_diff if quarter > yq(2000,1) & quarter<yq(2020,4)
local max = r(max)
local min = r(min)

twoway function y=`max',range(164 167) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(191 197) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(240 241) recast(area) color(gs12) base(`min') || ///
(tsline picore_diff if quarter > yq(2000,1) ,  lcolor(black) ) ||, ///
xtitle("") ytitle("Low- v. High-Income Core Inflation")   legend(off)       ///
tlabel(160(8)240, format(%tqCCYY))

graph export "output/income_level_inflation_core.png", replace


*For text (base period 2007,1)
gen cpidiff = cpi1_all - cpi5_all
gen cpidiff_core = cpi1_core - cpi5_core

sum cpidiff if quarter == yq(2012,4)
sum cpidiff_core if quarter == yq(2012,4)

*For model comparison
foreach var in cpi1_core cpi5_core cpi1_all cpi5_all{

   gen _`var'072 = `var' if quarter == yq(2007,3)
	egen `var'072 = max(_`var'072)
	gen `var'2 = 100*`var'/`var'072
	drop `var'072 _`var'072
}

sum cpi1_core2  if quarter == yq(2009,2)
local p1 = r(mean)
sum cpi5_core2 if quarter == yq(2009,2)
local p2 = r(mean)

di `p1'-`p2'

sum cpi1_all2  if quarter == yq(2009,2)
local p1 = r(mean)
sum cpi5_all2 if quarter == yq(2009,2)
local p2 = r(mean)

di `p1'-`p2'
