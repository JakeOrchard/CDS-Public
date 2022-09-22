/**********************************************************************;
* Project           : Competing for necessities
*
* Program name      : Create_filtered_pl_timeseries.do
*
* Author            : Jacob Orchard 
*
* Date created      : 5/17/2021
*
* Purpose           : Creates filtered time series of luxury v. necessity prices
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* 
**********************************************************************/

clear all

/******************************************************************************
0. Isolates by decade
*****************************************************************************/
local decadelist `"1990" "2000" "2010"'

foreach decade in "`decadelist'"{




/**************************************************************************
1. Pulls in price data
***************************************************************************/

global years 1967 1977 1987 1997

foreach year in $years{

freduse CPIAUCSL PCE, clear
gen quarter = qofd(daten)
collapse (mean) cpi = CPIAUCSL pce = PCE,by(quarter)
tempfile freddata
save `freddata'


use $CPI/sector_prices.dta, clear

tempfile prices

gen quarter = qofd(dofm(month))
format quarter %tq


collapse (mean) value, by(quarter CPIgroup CPICode CPICategory)
sort CPICategory quarter

merge m:1 CPICategory using  $CEX/consumption_shares_income`decade'.dta, nogen

gen necessity =ratio_total < 1 & ratio_total != .
drop if ratio_total == .

*Use 2007 dollars throughout
gen _value2007 = value if quarter == yq(2007,1)
egen value2007 = max(_value2007), by(CPICategory)
replace value = 100*(value/value2007)

*Converts to Real Prices
merge m:1 quarter using `freddata', keep(match)
gen _cpi2007 = cpi if quarter == yq(2007,1)
egen cpi2007 = max(_cpi2007)
replace cpi = cpi/cpi2007
replace value = value/cpi

*Creates a balanced sample post year
keep if quarter > yq(`year',4)
bys CPIgroup: gen number = _N
sum number
keep if number == r(max)
drop number

*Reindexes products 

drop CPIgroup
egen CPIgroup = group(CPICategory)
labmask CPIgroup, value(CPICategory)
xtset CPIgroup quarter


*Necessity and luxury average price
merge m:1 CPICategory using $CEX/CEX_durable.dta, nogen  keep(1 3)
keep if oil == 0 & transportation == 0

merge m:1 CPICategory quarter using $CEX/aggregate_shares`decade'.dta, keepusing(agg_share) nogen keep(1 3)

gen year = yofd(dofq(quarter))

*Average Shares for each price category


preserve
tempfile stoneweight
collapse (mean) agg_share, by(CPICategory)
egen total_share = sum(agg_share)

gen stoneweight = agg_share/total_share
keep CPICategory stoneweight

save `stoneweight'
restore


*Create Average Prices and Stone Index

xtset CPIgroup quarter

merge m:1 CPICategory using `stoneweight', nogen


egen total_type_share = sum(stoneweight),by(necessity quarter)
gen catshare = stoneweight/total_type_share


gen price = value/100

sort CPIgroup quarter

gen stone_index = catshare*((price/l.price))

collapse (count) ncat = stone_index (sum) stone_index , by(necessity quarter)

sort necessity quarter

by necessity: gen cum_stone = exp(sum((log(stone_index))))
gen lprice = log(cum_stone)


keep lprice stone_index quarter necessity cum_stone ncat
reshape wide lprice stone_index  cum_stone ncat, i(quarter) j(necessity)


sort quarter
tsset quarter


gen pn = lprice1-lprice0

drop if pn == 0
gen ncat = ncat0 + ncat1
sum ncat
local N`year' = r(max)

keep pn quarter
rename pn pn`year'



tempfile temp`year'
save `temp`year''

}


/*****************************************************************************
2. Graphs Index over time
***************************************************************************/
use `temp1967', clear

merge 1:1 quarter using `temp1977',nogen
merge 1:1 quarter using `temp1987',nogen
merge 1:1 quarter using `temp1997',nogen

*Number of observations



*Pulls in Recession Data
preserve
import fred UNRATE USRECQM, clear
generate quarter = qofd(daten)

collapse (mean) UNRATE USRECQM, by(quarter)
tempfile recession
save `recession'
restore

merge 1:1 quarter using `recession', keep(1 3)

*Filters Index
gen quarternum = quarter(dofq(quarter))
gen lu = log(UNRATE)

foreach var in pn1967 pn1977 pn1987 pn1997 UNRATE lu{
	
	reg `var' i.quarternum 
	predict `var'_sa, resid
	replace `var'_sa = `var'_sa + _b[_cons] 
	forval j = 2/4{

	replace `var'_sa = _b[`j'.quarternum]/4 + `var'_sa
	}
	
	reg `var'_sa l(8/11).`var'_sa //Filters using method in Hamilton 2017
	predict `var'_filter, resid
	
}




summarize pn1967_filter
local min = r(min)
local max = r(max)
 
 
set scheme s1color
*set scheme plotplainblind

       
       twoway function y=`max',range(55 60) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(80 82) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(86 91) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(122 124) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(164 167) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(191 197) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(240 242) recast(area) color(gs12) base(`min') || /// 
(tsline pn1967_filter,  lcolor(blue) ) || ///
(tsline pn1977_filter,  lcolor(black) lpattern("-")) || ///
(tsline pn1987_filter,  lcolor(green) lpattern(".-")) || ///
(tsline pn1997_filter, lcolor(red) lpattern("..-")) ||    ,         ///
legend(label(8 "N = `N1967'")  label(9 "N = `N1977'") label(10 "N = `N1987'") label(11 "N = `N1997'")  cols(2) rows(2) order( 8 9 10 11 ) subtitle("Balanced Sample") ) ///                                        ///
xtitle("") ytitle("Relative Necessity Prices")         ///
tlabel(40(40)240, format(%tqCCYY))
	   
graph export "output/time_series_relative_prices`decade'.png", replace

summarize pn1967_sa
local max = r(max)
local min = r(min)

if "`decade'" == "2010"{
	summarize pn1977_sa
	local min = r(min)

}

if "`decade'" == "1990"{
	summarize pn1997_sa
	local max = r(max)

}

twoway function y=`max',range(55 60) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(80 82) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(86 91) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(122 124) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(164 167) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(191 197) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(240 242) recast(area) color(gs12) base(`min') || /// 
(tsline pn1967_sa,  lcolor(blue) ) || ///
(tsline pn1977_sa,  lcolor(black) lpattern("-")) || ///
(tsline pn1987_sa,  lcolor(green) lpattern(".-")) || ///
(tsline pn1997_sa, lcolor(red) lpattern("..-")) ||    ,         ///
legend(label(8 "N = `N1967'")  label(9 "N = `N1977'") label(10 "N = `N1987'") label(11 "N = `N1997'")  cols(2) rows(2) order( 8 9 10 11 ) subtitle("Balanced Sample") ) ///                                        ///                                     ///
xtitle("") ytitle("Relative Necessity Prices")          ///
tlabel(40(40)240, format(%tqCCYY))

    
	   
	   
graph export "output/time_series_relative_prices_nofilter`decade'.png", replace

}
