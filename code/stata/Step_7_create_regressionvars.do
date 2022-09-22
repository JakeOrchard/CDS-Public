/***********************************************************************;
* Project           : Competing for necessities
*
* Program name      : Step_7_create_regressionvars.do
*
* Author            : Jacob Orchard
*
* Date created      : 07/22/2021
*
* Purpose           : Prepares aggregate monthly data for regressions
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 

**********************************************************************/


clear all

/*****************************************************************************
1. Merge Data
*******************************************************************************/

	use $CEX/clean_mtbi.dta, clear

	drop if CPICategory == ""

	gen quarter = yq(year,qtrnum)
	format quarter %tq
	cap drop _merge

	merge m:1 cuid quarter using $CEX/clean_fmli.dta, nogen keep(match) keepusing(insample finlwt21 total_spending intmonth )
	keep if insample
	egen onehh = tag(cuid intmonth)
	replace cost = 0 if cost < 0

	gen total_spending1 = total_spending*onehh

	*Aggregate Spending
	preserve 
	tempfile aggspend
	collapse (sum) total_spending1  [w=finlwt21], by(intmonth)
	label variable total_spending1 "Sum of Household Spending"
	save `aggspend'
	restore

	collapse (sum) cost [w=finlwt21], by(intmonth CPICategory)

	merge m:1 intmonth using `aggspend', nogen

	gen aggshare_month = cost/total_spending1


/******************************************************************************
2. Merge in Price data to construct real expenditure
*****************************************************************************/

	gen month = intmonth 

	merge 1:1 month CPICategory  using $CPI/sector_prices.dta, gen(matchprice)

	*Use 2007 January dollars throughout
	gen _value2007 = value if month == ym(2007,1)
	egen value2007 = max(_value2007), by(CPICategory)
	replace value = 100*(value/value2007)
	
	
	*Create Real Expenditure Series
	gen rcost = 100*(cost/value)
	gen lrcost = log(rcost)
	gen lshare = log(aggshare_month)
	
	*Merge in product level information
	merge m:1 CPICategory using  $CEX/consumption_shares_income.dta, nogen
	merge m:1 CPICategory using $CEX/CEX_durable.dta, nogen  keep(1 3)


	gen necessity =ratio_total > 1 & ratio_total != .
	drop if ratio_total == .
	
	*Reindexes products 

	drop CPIgroup
	egen CPIgroup = group(CPICategory)
	labmask CPIgroup, value(CPICategory)
	sort CPIgroup month
	xtset CPIgroup month
	
	*Balanced sample for prices 
	
	global years 1967 1977 1987 1997
	
	foreach year in $years{
	gen balance`year' = month > ym(`year',12) & value ~= .
	bys CPICategory balance`year': gen number = _N
	replace number = 0 if balance`year' == 0
	di `year'
	sum number
	replace balance`year' = 0 if number != r(max)
	drop number
	}
	

	*Average Shares for each price category


	preserve
	tempfile stoneweight
	collapse (mean) aggshare = aggshare_month, by(CPICategory)
	egen total_share = sum(aggshare)

	gen stoneweight = aggshare/total_share
	keep CPICategory stoneweight

	save `stoneweight'
	restore


	*Merges in weight


	merge m:1 CPICategory using `stoneweight', nogen

	
/******************************************************************************
3. Pulls in relevant monthly data from FRED
*****************************************************************************/
	

	preserve
	tempfile oneyear
	import fred dgs1 pce pcepi UNRATE cpiaucsl, clear
	gen month = mofd(daten)
	collapse (mean) pce = PCE pcepi = PCEPI dgs1 = DGS1 unrate = UNRATE cpi = CPI, by(month)
	sort month
	gen rX = 100*(pce/pcepi)
	gen lrX = log(rX)
	gen lpce = log(pce)
	gen cpi_pi = 100*(cpi-cpi[_n-12])/cpi[_n-12]
	gen lcpi = log(cpi)
	save `oneyear'
	restore

	merge m:1 month using `oneyear', keep(1 3) nogen
	
	*Converts to Real Prices
	gen _cpi2007 = cpi if month == ym(2007,1)
	egen cpi2007 = max(_cpi2007)
	replace cpi = cpi/cpi2007
	gen rprice = value/cpi
	gen lprice = log(rprice)
	
	*Generates independent regressors
	gen energy = oil | transportation 
	gen necessity_int = ratio_total*unrate
	gen energy_int = energy*unrate
	gen durable_int = durable*unrate
	gen service_int = service*unrate
	gen work_int = work*unrate
	
	*Drops housing from analysis
	drop if CPICategory == "Housing"
	
/******************************************************************************
4. Seasonally smooths consumption shares and expenditure
******************************************************************************/

gen monthnum = month(dofm(month))

local depvariablelist `"lshare" "lrcost"'


qui foreach var in "`depvariablelist'"{
	di `var'
	cap gen `var'_sa = .
	
	sum CPIgroup

forval i = 1/`r(max)'{
    
	noi di `i'
	if `i' == 39 | (`i' == 52 & "`var'" == "lrcost") | (`i' == 66 & "`var'" == "lrcost") | (`i' == 111 & "`var'" == "lrcost"){
	    continue
	}	
	


	reg `var' i.monthnum if CPIgroup == `i'
	predict `var'_sa`i', resid
	replace `var'_sa`i' = . if CPIgroup ~= `i'
	replace `var'_sa`i' = `var'_sa`i' + _b[_cons] 
	forval j = 2/12{

	replace `var'_sa`i' = _b[`j'.monthnum]/12 + `var'_sa`i'
	}
	
	replace `var'_sa = `var'_sa`i' if CPIgroup == `i'
	drop `var'_sa`i'
}

}

*Smooth the share data
sort CPIgroup month
xtset CPIgroup month

*Some missing data in some interviews for discreet purchases. This smooths the consumption data over three interviews

local smoothvars `"share" "rcost"'

foreach type in "`smoothvars'"{
gen CPIgroup`type' = CPIgroup
replace CPIgroup`type' = . if l`type' == .
sort CPIgroup month
gen first = CPIgroup`type' != . & l.CPIgroup`type' == .
by CPIgroup: replace first = first[_n-1] if first == 0
replace CPIgroup`type' = . if first != 1
drop first
sort CPIgroup`type' month
by CPIgroup`type': gen appearance`type' = _n
by CPIgroup`type': gen N`type' = _N
}

sort CPIgroup month
gen _lshare_sa = lshare_sa
gen _lrcost_sa = lrcost_sa
replace _lshare_sa = 0 if lshare_sa == . & appearanceshare > 2
replace _lrcost_sa = 0 if lrcost_sa == . & appearancercost > 2

gen lshare_sa_smooth = 1/3*(_lshare_sa + l._lshare_sa + l2._lshare_sa)
gen lrcost_sa_smooth = 1/3*(_lrcost_sa + l._lrcost_sa + l2._lrcost_sa)
replace lshare_sa_smooth = . if lshare == .
replace lrcost_sa_smooth = . if lrcost == .

*Drops first and last 2 observations
replace lshare_sa_smooth = . if appearanceshare <3
replace lshare_sa_smooth = . if appearanceshare > Nshare -3
replace lrcost_sa_smooth = . if appearancercost <3 
replace lrcost_sa_smooth = . if appearancercost > Nrcost-3


*For now, end sample at end of 2021
keep if month < ym(2022,1)

label data "Monthly Regression Data: Step_7_create_regressionvars.do 7/28/2021"

save $CEX/clean_regression_vars.dta, replace
	
	
	
	

