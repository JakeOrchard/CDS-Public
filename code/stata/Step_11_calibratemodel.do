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



/******************************************************************************
1. Pulls in expenditure data, merges with prices, and other setup
*******************************************************************************/




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

merge m:1 CPICategory using $CEX/CEX_durable.dta, nogen
replace oil = 0 if oil == .
replace transportation = 0 if transportation == .
*keep if durable == 0 & oil == 0 & transportation == 0
drop if CPICategory == ""

*Removes housing expenditures and energy from total_spending
gen _housingcost = cost if CPICategory == "Housing"
egen housingcost = sum(_housingcost), by(cuid quarter)

gen _energycost = cost if transportation | oil
egen energycost = sum(_energycost), by(cuid quarter)

gen total_spendingNH = total_spending - housingcost 
gen total_spendingNH_NE = total_spending - housingcost -energycost //Used for time series 


drop if CPICategory == "Housing" 

gen costne = cost 
replace costne = 0 if oil | transportation

collapse (mean) finlwt21 income_group age fam_size income no_earnr total_spendingNH total_spendingNH_NE (sum) cost costne , by(necessity cuid quarter)


gen _nshare = cost/total_spendingNH if necessity == 1
egen nshare = max(_nshare), by(cuid quarter)

gen _lshare = cost/total_spendingNH if necessity == 0
egen lshare = max(_lshare), by(cuid quarter)

*Average nshare and expenditure level by income_group in 2005-06

preserve

keep if quarter <yq(2007,1) & quarter > yq(2004,4)
keep if necessity == 1

collapse (mean) nshare total_spendingNH  [w=finlwt21], by(income_group)

export delimited using "$CEX/data_moments.csv", replace
restore



keep quarter cuid finlwt21 age fam_size income income_group no_earnr total_spendingNH nshare lshare necessity cost total_spendingNH_NE costne

drop if necessity == .

sort cuid quarter necessity
bys cuid quarter: gen numb = _N
sum numb 
keep if numb == 2

*Merge with price series from step 5

merge m:1 quarter using $CPI/pnseries.dta, nogen


*Converts to 2007 dollars 
gen _cpi2007 = cpi if quarter == yq(2007,1)
egen cpi2007 = max(_cpi2007)
replace cpi = cpi/cpi2007

*Converts from relative necessity price to relative luxury price (in model)

foreach var of varlist pn*{
	
	gen pl`var' = 1/`var'
	
}


*Pull in monetary shock
preserve



import excel "$rawdata/pre-and-post-ZLB factors_extended.xlsx", sheet("Data") cellrange(B2:F253) firstrow clear

gen quarter = qofd(date(B,"DMY"))
drop if quarter == .

rename F negative_LSAP

collapse (sum) Federal-negative, by(quarter)

*Gets rid of missing values
replace FederalFundsRate = 0 if FederalFundsRate == . & quarter > yq(1988,4) & quarter < yq(2019,1)
replace Forward = 0 if Forward == . & quarter > yq(1988,14) & quarter < yq(2019,1)
replace negative_LSAP = 0 if LSAP == . & quarter > yq(1988,4) & quarter < yq(2019,1)

tsset quarter

*Creates lags of monetary shock

forval i = 4/8{
gen l`i'FFR_factor = l`i'.FederalFundsRate

}

save $temp/swanson_quarter.dta, replace

restore

preserve

*Creates lags of CPI
collapse (mean) cpi dgs1 unrate = UNRATE, by(quarter)


foreach var of varlist cpi dgs1 unrate{
	forval i = 4/8{
	gen l`i'`var' = l`i'.`var'

	}
}

tempfile lagvars
save `lagvars'

restore

merge m:1 quarter using $temp/swanson_quarter.dta, nogen
merge m:1 quarter using `lagvars', nogen 

keep if necessity == 1


/******************************************************************************
3. Estimated Luxury and Necessity share of Representative Household 
*******************************************************************************/

preserve
collapse (sum) cost costne total_spendingNH_NE total_spendingNH [w=finlwt21],by(quarter)

gen agg_n = cost/total_spendingNH
gen agg_n_ne = costne/total_spendingNH_NE
di "Necessity Share of Representative Agent"

sum agg_n if quarter < yq(2007,1) & quarter > yq(2004,4)
sum agg_n_ne if quarter < yq(2007,1) & quarter > yq(2004,4)

tempfile agg_sn
save `agg_sn'

restore


merge m:1 quarter using `agg_sn', nogen



/******************************************************************************
4. Expenditure of representative agent
*******************************************************************************/

preserve
tempfile repexp

egen xmean = wtmean(total_spendingNH), weight(finlwt21) by(quarter)


gen ratio = total_spendingNH/xmean
gen lratio = log(ratio)
gen product = ratio*lratio

collapse (mean) xmean product [w=finlwt21], by(quarter)

rename product theil

gen Xr = xmean*exp(theil)

di "Expenditure of Representative Agent"
sum Xr if quarter < yq(2007,1) & quarter > yq(2004,4)


save `repexp'
restore

merge m:1 quarter using `repexp', nogen 

/******************************************************************************
4. AIDS estimation
*******************************************************************************/


gen lspend = log(total_spendingNH) 
gen rlspend = lspend - log(cpi)
gen rspend = exp(rlspend)
gen lincome = log(income)

sum agg_n if quarter < yq(2007,1) & quarter > yq(2004,4)
//share in 2005-06
local sn = r(mean)
local sl = 1-r(mean)
di `sn'
di `sl'

sum plpn1987_sa if quarter < yq(2007,1) & quarter > yq(2004,4)
 //price in 2007
local pl = r(mean)


sum Xr if quarter < yq(2007,1) & quarter > yq(2004,4)

local xr = r(mean)


*OLS
ivreghdfe nshare plpn1987_sa rlspend [w=finlwt21], absorb(age fam_size no_earnr) robust
eststo

*Income Elasticity:
local _lux_exp_elas =  1- _b[rlspend]/`sl'
local _nes_exp_elas =  1+_b[rlspend]/`sn'


*Own Price Elasticity
local _lux_own_elas = -1-_b[plpn1987_sa]/`sl' + (_b[rlspend]/`sl')*( `sn' - _b[rlspend] *log(`xr'))
local _nes_own_elas = -1 -_b[plpn1987_sa]/`sn' - (_b[rlspend]/`sn')*( `sl' + _b[rlspend] *log(`xr'))

*Cross Price Elasticity
local _lux_cross_elas = _b[plpn1987_sa]/`sl' + (_b[rlspend]/`sl')*( `sn' - _b[rlspend] *log(`xr'))
local _nes_cross_elas =  _b[plpn1987_sa]/`sn' - (_b[rlspend]/`sn')*( `sl' + _b[rlspend] *log(`xr'))

*Round and add to results (formatting later does not seem to work for these locals)

qui estadd local lux_exp_elas = round(`_lux_exp_elas',.01)
qui estadd local nes_exp_elas = round(`_nes_exp_elas',.01)
qui estadd local lux_own_elas = round(`_lux_own_elas',.01)
qui estadd local nes_own_elas = round(`_nes_own_elas',.01)
qui estadd local lux_cross_elas = round(`_lux_cross_elas',.01)
qui estadd local nes_cross_elas = round(`_nes_cross_elas',.01)

scalar gammaln = _b[plpn1987_sa]
scalar betan = _b[rlspend]


*IV--INCOME

ivreghdfe nshare plpn1987_sa (rlspend = lincome i.income_group) [w=finlwt21], absorb(age fam_size no_earnr) robust
eststo
*Income Elasticity:
local _lux_exp_elas =  1- _b[rlspend]/`sl'
local _nes_exp_elas =  1+_b[rlspend]/`sn'

*Own Price Elasticity
local _lux_own_elas = -1-_b[plpn1987_sa]/`sl' + (_b[rlspend]/`sl')*( `sn' - _b[rlspend] *log(`xr'))
local _nes_own_elas = -1 -_b[plpn1987_sa]/`sn' - (_b[rlspend]/`sn')*( `sl' + _b[rlspend] *log(`xr'))

*Cross Price Elasticity
local _lux_cross_elas = _b[plpn1987_sa]/`sl' + (_b[rlspend]/`sl')*( `sn' - _b[rlspend] *log(`xr'))
local _nes_cross_elas = _b[plpn1987_sa]/`sn' - (_b[rlspend]/`sn')*( `sl' + _b[rlspend] *log(`xr'))


*Round and add to results (formatting later does not seem to work for these locals)
qui estadd local lux_exp_elas = round(`_lux_exp_elas',.01)
qui estadd local nes_exp_elas = round(`_nes_exp_elas',.01)
qui estadd local lux_own_elas = round(`_lux_own_elas',.01)
qui estadd local nes_own_elas = round(`_nes_own_elas',.01)
qui estadd local lux_cross_elas = round(`_lux_cross_elas',.01)
qui estadd local nes_cross_elas = round(`_nes_cross_elas',.01)


/*
*IV -- MONETARY POLICY SHOCK

ivreghdfe nshare plpn1987_sa (rlspend = l4* l5* l6* l7* l8*) [w=finlwt21], absorb(age fam_size no_earnr) robust

predict new_nshare, xb
eststo
*Income Elasticity:
local _lux_exp_elas =  1- _b[rlspend]/`sl'
local _nes_exp_elas =  1+_b[rlspend]/`sn'


*Own Price Elasticity
local _lux_own_elas = -1-_b[plpn1987_sa]/`sl' + (_b[rlspend]/`sl')*( `sn' - _b[rlspend] *log(`xr'))
local _nes_own_elas = -1 -_b[plpn1987_sa]/`sn' - (_b[rlspend]/`sn')*( `sl' + _b[rlspend] *log(`xr'))

*Cross Price Elasticity
local _lux_cross_elas = _b[plpn1987_sa]/`sl' + (_b[rlspend]/`sl')*( `sn' - _b[rlspend] *log(`xr'))
local _nes_cross_elas =  _b[plpn1987_sa]/`sn' - (_b[rlspend]/`sn')*( `sl' + _b[rlspend] *log(`xr'))


*Round and add to results (formatting later does not seem to work for these locals)

qui estadd local lux_exp_elas = round(`_lux_exp_elas',.01)
qui estadd local nes_exp_elas = round(`_nes_exp_elas',.01)
qui estadd local lux_own_elas = round(`_lux_own_elas',.01)
qui estadd local nes_own_elas = round(`_nes_own_elas',.01)
qui estadd local lux_cross_elas = round(`_lux_cross_elas',.01)
qui estadd local nes_cross_elas = round(`_nes_cross_elas',.01)

*/


/******************************************************************************
5.	Export Table
*******************************************************************************/

			local nregs = 2
			local nregs1 = `nregs'+1
			local keepvars `"plpn1987_sa rlspend"'
			local order `"plpn1987_sa rlspend"'
			local indicate
			local groups1 `"& \multicolumn{1}{c}{OLS} & \multicolumn{1}{c}{IV $-$ Income} \\"'
			local midrules1 `" \cmidrule(l{.75em}){2-`nregs1'}  \\"'
			local stype `"  & \multicolumn{1}{c}{ $ s^h_{n,t} $} & \multicolumn{1}{c}{ $ s^h_{n,t} $} "'
			local lower `" `stype'   \\  "'
			local groups `" "`groups1'  `midrules1' `lower' "  "'

			local stats "lux_exp_elas nes_exp_elas lux_own_elas nes_own_elas lux_cross_elas nes_cross_elas  N"
			local stats_fmt " %3s %12.2f %12.0fc"
			local stats_label `" `"Luxury Expenditure Elasticity"'  `"Necessity Expenditure Elasticity"' `"Luxury Own Price Elasticity"' `"Necessity Own Price Elasticity"'    `"Luxury Cross-Price Elasticity"'  `"Necessity Cross-Price Elasticity"' `"Observations"' "'
			local num_stats: word count `stats'

			local layout
			forvalues l = 1/`num_stats' {
				local layout `"`layout' "\multicolumn{1}{c}{@}" "'
			}
			local filename "table_micro_calibration"
			local dropvars 
			local table_preamble `" "\begin{table}[!t] \centering \sisetup{table-format=1.2} \def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}"   "\begin{tabularx}{\hsize}{@{\hskip\tabcolsep\extracolsep\fill}l*{`nregs'}{S}}" "\\" "\hline\hline" "'
			local prehead `"prehead(`table_preamble' `groups')"'			
			local posthead `"posthead(`"\hline"' `"\multicolumn{`=`nregs'+1'}{l}{Parameter Estimates:}\\"' `"\\"')"'
			local notes `"Notes: The unit of observation is the household-quarter.  Robust standard errors in parentheses.  "'
			local prefoot(" ")
			local postfoot `"postfoot(`"\hline \hline \end{tabularx} \begin{minipage}{\hsize} \rule{0pt}{9pt} \footnotesize `notes'  \end{minipage} \label{tab:`filename'} \end{table}"')"'
			
			esttab * using "$output/`filename'.tex",  replace cells(b(star fmt(a2)) se(par fmt(a2) abs)) starlevels( \$^{*}$ 0.1 \$^{**}$ 0.05 \$^{***}$ 0.01  ) drop(`dropvars', relax) keep(`keepvars') indicate(`indicate') `prehead' `posthead' `postfoot' order(`order') label coeflabels( plpn1987_sa "$\gamma_{NL}$" rlspend "$\beta^N$") stats(`stats', layout(`layout') fmt(`stats_fmt') labels(`stats_label')) collabels(,none) numbers nomtitles substitute(# `" X "' tabular* tabularx `"{1}{c}{("' `"{1}{L}{("') width(\hsize)
			
	
		
				estimates drop _all



				
/******************************************************************************
6.	Saves data for use in future do files (Step 12 create data time series)
*******************************************************************************/

save $CEX/quarterly_calibration_data.dta, replace





