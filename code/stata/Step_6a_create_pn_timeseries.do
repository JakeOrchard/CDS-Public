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


/**************************************************************************
1. Pulls in price data
***************************************************************************/

local energylist `"oil == 0 & transportation == 0" "ratio_total!=." "oil == 0 & transportation == 0 & durable == 0"'

global years 1967 1977 1987 1997

foreach energy in "`energylist'"{
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

	merge m:1 CPICategory using  $CEX/consumption_shares_income.dta, nogen

	gen necessity =ratio_total > 1 & ratio_total != .
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

	merge m:1 CPICategory quarter using $CEX/aggregate_shares.dta, keepusing(agg_share) nogen keep(1 3)
	keep if `energy'

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

	gen stone_index = catshare*(log(price/l.price))

	collapse (count) ncat = stone_index (sum) stone_index , by(necessity quarter)

	sort necessity quarter
	
	gen geo_index = exp(stone_index)

	by necessity: gen cum_stone = exp(sum((log(geo_index))))
	gen lprice = log(cum_stone)


	keep lprice stone_index quarter necessity cum_stone ncat 
	reshape wide lprice stone_index  cum_stone ncat, i(quarter) j(necessity)


	sort quarter
	tsset quarter


	gen pn = exp(lprice1-lprice0)
	
	local oilname ""
	if "`energy'" == "ratio_total!=."{
			
			local oilname "woil"
		}
	if "`energy'" == "oil == 0 & transportation == 0 & durable == 0"{
			
			local oilname "nondurable"
		}
	drop if pn == 0
	gen ncat = ncat0 + ncat1
	sum ncat
	local N`year'`oilname' = r(max)

	

	
	keep pn quarter 
	rename pn pn`year'`oilname'



	tempfile temp`year'`oilname'
	save `temp`year'`oilname''

	}

}
/*****************************************************************************
2. Graphs Index over time
***************************************************************************/
use `temp1967', clear

merge 1:1 quarter using `temp1977',nogen
merge 1:1 quarter using `temp1987',nogen
merge 1:1 quarter using `temp1997',nogen
merge 1:1 quarter using `temp1967woil',nogen
merge 1:1 quarter using `temp1977woil',nogen
merge 1:1 quarter using `temp1987woil',nogen
merge 1:1 quarter using `temp1997woil',nogen
merge 1:1 quarter using `temp1967nondurable',nogen
merge 1:1 quarter using `temp1977nondurable',nogen
merge 1:1 quarter using `temp1987nondurable',nogen
merge 1:1 quarter using `temp1997nondurable',nogen

*Number of observations

*Pulls in Recession Data
preserve
import fred UNRATE USRECQM CPIAUCSL PCE dgs1, clear
generate quarter = qofd(daten)

collapse (mean) UNRATE USRECQM  cpi = CPIAUCSL pce = PCE dgs1 = DGS1, by(quarter)
tsset quarter
tssmooth ma maU = UNRATE, window(20 0 20)
gen aboveU = UNRATE > maU
tempfile recession
save `recession'
restore

merge 1:1 quarter using `recession', keep(1 3)

*Filters Index
gen quarternum = quarter(dofq(quarter))
gen lu = log(UNRATE)

foreach var in pn1967 pn1977 pn1987 pn1997 pn1967woil pn1977woil pn1987woil pn1997woil pn1967nondurable pn1977nondurable pn1987nondurable pn1997nondurable UNRATE lu{
	
	reg `var' i.quarternum 
	predict `var'_sa, resid
	replace `var'_sa = `var'_sa + _b[_cons] 
	forval j = 2/4{

	replace `var'_sa = _b[`j'.quarternum]/4 + `var'_sa
	}
	
	reg `var'_sa l(8/11).`var'_sa //Filters using method in Hamilton 2018
	predict `var'_filter, resid
	
}




summarize pn1967_filter
generate recession = r(max) if USREC == 1
replace recession  = r(min) if USREC == 0
local min = r(min)
local max = r(max)
 
 reg pn1967_filter USRECQM
  reg pn1977_filter USRECQM
 reg pn1987_filter USRECQM
 reg pn1997_filter USRECQM

 
set scheme s1color
*set scheme plotplainblind

*Graphs with and without energy and transportation sectors

local oillist `"" "woil" "nondurable"'



foreach oil in "`oillist'"{
	
	if "`oil'" == "woil"{
		local N1967= `N1967woil'
		local N1977= `N1977woil'
		local N1987= `N1987woil'
		local N1997= `N1997woil'
	}
	if "`oil'" == "nondurable"{
		local N1967= `N1967nondurable'
		local N1977= `N1977nondurable'
		local N1987= `N1987nondurable'
		local N1997= `N1997nondurable'
	}
summarize pn1967`oil'_filter
local min = r(min)
local max = r(max)

twoway function y=`max',range(55 60) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(80 82) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(86 91) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(122 124) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(164 167) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(191 197) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(240 242) recast(area) color(gs12) base(`min') || /// 
(tsline pn1967`oil'_filter,  lcolor(blue) ) || ///
(tsline pn1977`oil'_filter,  lcolor(black) lpattern("-")) || ///
(tsline pn1987`oil'_filter,  lcolor(green) lpattern(".-")) || ///
(tsline pn1997`oil'_filter, lcolor(red) lpattern("..-")) ||    ,         ///
legend(label(8 "N = `N1967'")  label(9 "N = `N1977'") label(10 "N = `N1987'") label(11 "N = `N1997'")  cols(2) rows(2) order( 8 9 10 11 ) subtitle("Balanced Sample") ) ///                                        ///
xtitle("") ytitle("Relative Necessity Prices")         ///
tlabel(40(40)240, format(%tqCCYY))

	   
graph export "output/time_series_relative_prices`oil'.png", replace

summarize pn1967`oil'_sa
local max = r(max)
local min = r(min)

if "`oil'" == "woil"{
	summarize pn1997`oil'_sa
	local max = r(max)

}
    


twoway function y=`max',range(55 60) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(80 82) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(86 91) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(122 124) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(164 167) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(191 197) recast(area) color(gs12) base(`min') || /// 
function y=`max',range(240 242) recast(area) color(gs12) base(`min') || /// 
(tsline pn1967`oil'_sa,  lcolor(blue) ) || ///
(tsline pn1977`oil'_sa,  lcolor(black) lpattern("-")) || ///
(tsline pn1987`oil'_sa,  lcolor(green) lpattern(".-")) || ///
(tsline pn1997`oil'_sa, lcolor(red) lpattern("..-")) ||    ,         ///
legend(label(8 "N = `N1967'")  label(9 "N = `N1977'") label(10 "N = `N1987'") label(11 "N = `N1997'")  cols(2) rows(2) order( 8 9 10 11 ) subtitle("Balanced Sample") ) ///                                        ///                                     ///
xtitle("") ytitle("Relative Necessity Prices")          ///
tlabel(40(40)240, format(%tqCCYY))

    
	   
graph export "output/time_series_relative_prices_nofilter`oil'.png", replace

}

*Save quarterly data

label data "From Step_5_create_pn_timeseries: 12/13/2021"

save $CPI/pnseries.dta, replace



/*****************************************************************************
3. Regression Results and scatter plot
***************************************************************************/

sum quarter
gen timetrend = quarter-r(min)
gen timetrendsq = timetrend^2
foreach year in $years{
  


 newey pn`year'woil UNRATE timetrend timetrendsq, lag(2)
 eststo
  qui estadd local excludeoil `"No"'

    newey pn`year' UNRATE timetrend timetrendsq, lag(2)
 eststo
 qui estadd local excludeoil `"Yes"'
}




/******************************************************************************
Export Regression Table
*******************************************************************************/

		local nregs = 8
		local nregs1 = `nregs'+1
		local keepvars `"UNRATE"'
		local order `"UNRATE"'
		local indicate
		local groups1 `"& \multicolumn{`nregs'}{c}{`depname'} \\"'

		local midrules1 `" \cmidrule(l{.75em}){2-`nregs1'}  \\"'
		local stype `" & \multicolumn{2}{c}{1967 Series} & \multicolumn{2}{c}{1977 Series} & \multicolumn{2}{c}{ 1987 Series} & \multicolumn{2}{c}{1997 Series}"'
		local lower `" `stype'   \\  "'
		local groups `" "`groups1'  `midrules1' `lower' "  "'

		local stats " excludeoil  N"
		local stats_fmt " %3s %12.2f %12.0fc"
		local stats_label `" `"Exclude Oil and Transportation"' `"Observations"' "'
		local num_stats: word count `stats'

		local layout
		forvalues l = 1/`num_stats' {
			local layout `"`layout' "\multicolumn{1}{c}{@}" "'
		}
		local dropvars 
		local title `"Relative Necessity Price and Unemployment"'
		local table_preamble `" "\begin{table}[!t] \centering \sisetup{table-format=1.2} \def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" "\caption{`title'}"   "\label{table:pnunrate}""\begin{tabularx}{\hsize}{@{\hskip\tabcolsep\extracolsep\fill}l*{`nregs'}{S}}" "\\" "\hline\hline" "'
		local prehead `"prehead(`table_preamble' `groups')"'			
		local posthead `"posthead(`"\hline"' `"\multicolumn{`=`nregs'+1'}{l}{Right hand side variables:}\\"' `"\\"')"'
		local notes `"Notes: Newey-West HAC Standard errors in parentheses.  \$ \:^{*}\:p<0.1,\:\:^{**}\:p<0.05,\:\:^{***}\:p<0.01 \$ . The dependent variable is the unfiltered log difference in price between the aggregate necessity good and the aggregate luxury good.  All regressions include a linear and quadratic time trend.   "'
		local filename `"table_pn_unrate"'
		local prefoot(" ")
		local postfoot `"postfoot(`"\hline\hline \end{tabularx} \begin{minipage}{\hsize} \rule{0pt}{9pt} \footnotesize `notes'  \end{minipage} \label{tab:`filename'} \end{table}"')"'
		esttab * using "$output/`filename'.tex",  replace cells(b(star fmt(a2)) se(par fmt(a2) abs)) starlevels( \$^{*}$ 0.1 \$^{**}$ 0.05 \$^{***}$ 0.01  ) drop(`dropvars', relax) keep(`keepvars') indicate(`indicate') `prehead' `posthead' `postfoot' order(`order') label coeflabels( UNRATE "Unemployment Rate") stats(`stats', layout(`layout') fmt(`stats_fmt') labels(`stats_label')) collabels(,none) numbers nomtitles substitute(# `" X "' tabular* tabularx `"{1}{c}{("' `"{1}{L}{("') width(\hsize)
		estimates drop _all

		
/*****************************************************************
		Scatter Plot
********************************************************************/

binscatter pn1997_filter UNRATE, xtitle("Unemployment Rate") ytitle("Relative Necessity Prices (1997 Series)") nq(10) reportreg
graph export "output/pnfilter1997_urate.png", replace

binscatter pn1987_filter UNRATE, xtitle("Unemployment Rate") ytitle("Relative Necessity Prices (1987 Series)") nq(10) reportreg
graph export "output/pnfilter1987_urate.png", replace

binscatter pn1977_filter UNRATE, xtitle("Unemployment Rate") ytitle("Relative Necessity Prices (1977 Series)") nq(10) reportreg
graph export "output/pnfilter1977_urate.png", replace

binscatter pn1967_filter UNRATE, xtitle("Unemployment Rate") ytitle("Relative Necessity Prices (1967 Series)") nq(10) reportreg
graph export "output/pnfilter1967_urate.png", replace
