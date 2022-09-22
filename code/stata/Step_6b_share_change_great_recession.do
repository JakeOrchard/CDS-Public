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
version 15

*Directories


/*****************************************************************************
0. Program To Feed into Bootstrap
*****************************************************************************/

program aggregate_sn, rclass
	*Input: Cross-Sectional Consumption data (i.e. one quarter)
	*Output: Aggregate Necessity Share
	version 15
	preserve
		bsample 
		
		collapse   (sum) cost0 cost1 [w=finlwt21]
		gen total_spending = cost0+cost1
		gen nshare = cost1/total_spending 
		sum nshare
		local _asn = r(mean)
		return scalar asn = `_asn'
	restore
end


/*****************************************************************************
1. Imports Consumer expenditure data
******************************************************************************/


local keepdurables `"" "&durable == 1"'

local timelist `"year" "quarter"'


local samplelist `"insample" "all"'


foreach time in "`timelist'"{
	
	if  "`time'" == "year"{
	
	local maxtime 2021
	local mintime 1990
	
}

if  "`time'" == "quarter"{
	
	local maxtime 244
	local mintime 121
	
}

	
foreach kdur in "`keepdurables'"{
	

foreach sample in "`samplelist'"{


use $CEX/clean_mtbi.dta, clear


gen quarter = yq(year,qtrnum)
format quarter %tq
cap drop _merge

*Removes negative spending
replace cost = 0 if cost < 0

merge m:1 cuid quarter using $CEX/clean_fmli.dta, nogen keep(match) keepusing(insample finlwt21 total_spending income_group intmonth income fam_size age  no_earnr)

merge m:1 CPICategory using  $CEX/consumption_shares_income.dta, nogen
merge m:1 CPICategory using $CEX/CEX_durable.dta, nogen  keep(1 3)

gen all = 1

keep if `sample'

gen necessity =ratio_total > 1 & ratio_total != .
drop if ratio_total == .

*Removes housing expenditures and energy from total_spending
gen _removecost = cost if CPICategory == "Housing" `kdur'
egen removecost = sum(_removecost), by(cuid quarter)


gen total_spendingNH = total_spending - removecost 

drop if CPICategory == "Housing" `kdur'
egen onehhq = tag(cuid quarter)

gen total_spending1 = total_spendingNH*onehhq


collapse (max) finlwt21   (sum) cost total_spending1, by(necessity cuid `time')






/*****************************************************************************
2. Creates CI of aggregate SN by bootstrapping
******************************************************************************/

egen _finlwt21 = max(finlwt21), by(`time' cuid)
replace finlwt21 = _finlwt21

rename total_spending1 total_spending
label data "Data for Bootstrap"
reshape wide cost total_spending, i(finlwt21 cuid `time') j(necessity)

replace total_spending0 = 0 if total_spending0 == .
replace total_spending1 = 0 if total_spending1 == .

gen total_spending = total_spending0 + total_spending1
save $temp/temp_bstrap.dta, replace
 

*Creates temporary dataset to store results
clear
tempfile results
cap drop asn asnH asnL
cap drop quarter
cap drop year
local timeperiods = `maxtime' - `mintime' + 1
di `timeperiods'
set obs `timeperiods'

gen obsnum = _n
gen `time' = .
gen asn = .
gen asnH = .
gen asnL = .
	

save `results'

local counter   1

forval i = 	`mintime'/`maxtime'{
di `i'
 use $temp/temp_bstrap.dta, clear
   
	keep if `time' == `i'
	
local N = round(_N/2)
di `N'

preserve		
		collapse   (sum) cost0 cost1 total_spending [w=finlwt21]
		gen nshare = cost1/total_spending 
		sum nshare
		scalar observed_asn = r(mean)
	restore


simulate asn = r(asn), reps(1000) seed(12345): aggregate_sn

bstat, stat(observed_asn) n(`N') level(90)

estat bootstrap, bc
mat A = e(ci_normal)
scalar ll = A[1,1]
scalar ul = A[2,1]

use `results', clear

di `counter'
replace `time' = `i' if obsnum == `counter'

replace asn = observed_asn if `time' == `i'
replace asnH = ul if `time' == `i'
replace asnL = ll if `time' == `i'
save `results', replace


local counter = `counter' + 1

}


use `results', clear
tsset `time'
cap gen year = yofd(dofq(quarter))

if  "`kdur'" == ""{
	
	local elabel = ""
}

else if  "`kdur'" == "&durable == 1"{
	
	local elabel = "_nondurables"
}


if 	"`time'" == "year"{

tsline asn asnH asnL if `time' > 1990 , xaxis(1 2) xlabel(1992(4)2020, axis(1)) xtitle(Year, axis(1)) xtitle("",axis(2)) ytitle(Necessity Share) bgcolor(white) graphregion(color(white)) legend(off) lcolor( blue gray gray) lpattern(1 - -) xla(2001 `" "2001" "Recession" "' 2007 `" "Financial" "Crisis" "' 2013 `" "Per-Capita GDP" "Recovery" "' 2020 "Covid-19" , axis(2)) tline(2001 2007 2013 2020, lpattern(dot))


graph export output/necessity_share_wci`elabel'`sample'`time'.png, replace

}
else{
	format quarter %tq
	local snlist `"asn" "asnH" "asnL"'

	*Seasonally smooth
	qui foreach var in "`snlist'"{
	di `var'
	cap gen quarternum = quarter(dofq(quarter))
	



	reg `var' i.quarternum
	predict `var'_sa, resid
	replace `var'_sa = `var'_sa + _b[_cons] 
	forval j = 2/4{

	replace `var'_sa = _b[`j'.quarternum]/4 + `var'_sa
	}
	
	

}
	
tsline asn_sa asnH_sa asnL_sa if year > 1990, xaxis(1 2) xlabel(128(12)244, axis(1)) xtitle(Quarter, axis(1)) xtitle("",axis(2)) ytitle(Necessity Share) bgcolor(white) graphregion(color(white)) legend(off) lcolor( blue gray gray) lpattern(1 - -) xla( 164 `" "2001" "Recession" "' 191 `" "Financial" "Crisis" "' 214 `" "Per-Capita GDP" "Recovery" "' 240 "Covid-19" , axis(2)) tline(164 191 214 240, lpattern(dot))


graph export output/necessity_share_wci`elabel'`sample'`time'.png, replace
	
}

 
 /************************************************************************************
 3. Imports PCE expenditure and computed PN/PL prices
 *************************************************************************************/
 
preserve
freduse DHSGRC0 PCE PCEDG PCEPI, clear
gen quarter = qofd(daten)
gen year = yofd(daten)

collapse (mean) PCEPI PCE PCEDG PCE_housing = DHSGRC0, by(quarter year)

*Merge in computed PN/PL prices 

merge 1:1 quarter using $CPI/pnseries.dta, gen(price_merge)

*REAL PCE in 2007 Q1 Dollars
gen _PCEPI2007 = PCEPI if quarter == yq(2007,1)
egen PCEPI2007 = max(_PCEPI2007)
replace PCEPI = 100*PCEPI/PCEPI2007
replace PCE = 100*PCE/PCEPI
replace PCEDG = 100*PCEDG/PCEPI
replace PCE_housing = PCE_housing/(10*PCEPI)

gen PCE_nohousing = PCE-PCE_housing
gen PCE_nondurable_nohousing = PCE-PCE_housing - PCEDG


if	"`time'" == "year"{
collapse (mean) PCE PCE_housing PCE_nohousing PCE_nondurable_nohousing pn1987, by(year)
}
tempfile PCE
save `PCE'
restore

if	"`time'" == "year"{
merge 1:1 year using `PCE', nogen keep(match)
}
else{
	merge 1:1 year quarter using `PCE', nogen keep(match)
}

if  "`kdur'" == ""{
	
gen Xn = asn*PCE_nohousing
gen Xl = (1-asn)*PCE_nohousing
gen X = PCE_nohousing

}

else if  "`kdur'" == "&durable == 1"{
	
gen Xn = asn*PCE_nondurable_nohousing
gen Xl = (1-asn)*PCE_nondurable_nohousing
gen X = PCE_nondurable_nohousing
}


gen Xnr = Xn/pn1987
gen Xlr = Xl*pn1987

gen asnr = asn/pn1987

gen asnrH = asnH/pn1987
gen asnrL = asnL/pn1987


if	"`time'" == "year"{
tsline Xn Xl  if year > 1990 , xaxis(1 2) xlabel(1992(4)2020, axis(1)) xtitle(Year, axis(1)) xtitle("",axis(2)) ytitle(Billions of Dollars) bgcolor(white) graphregion(color(white)) legend(order(1 "Necessities" 2 "Luxuries")) lcolor( blue gray ) lpattern(1 1) xla(2001 `" "2001" "Recession" "' 2007 `" "Financial" "Crisis" "' 2013 `" "Per-Capita GDP" "Recovery" "' 2020 "Covid-19" , axis(2)) tline(2001 2007 2013 2020, lpattern(dot))



graph export output/NL_PCE_expenditures`elabel'`sample'`time'.png, replace
	
	
tsline Xn Xl X if year > 1990 , xaxis(1 2) xlabel(1992(4)2020, axis(1)) xtitle(Year, axis(1)) xtitle("",axis(2)) ytitle(Billions of Dollars) bgcolor(white) graphregion(color(white)) legend(order(1 "Necessities" 2 "Luxuries" 3 "Total")) lcolor( blue gray black ) lpattern(1 1) xla(2001 `" "2001" "Recession" "' 2007 `" "Financial" "Crisis" "' 2013 `" "Per-Capita GDP" "Recovery" "' 2020 "Covid-19" , axis(2)) tline(2001 2007 2013 2020, lpattern(dot))

graph export output/NL_PCE_expenditures`elabel'`sample'`time'_wtotal.png, replace

tsline Xnr Xlr if year > 1990 , xaxis(1 2) xlabel(1992(4)2020, axis(1)) xtitle(Year, axis(1)) xtitle("",axis(2)) ytitle(Billions of Dollars) bgcolor(white) graphregion(color(white)) legend(order(1 "Necessities" 2 "Luxuries")) lcolor( blue gray ) lpattern(1 1) xla(2001 `" "2001" "Recession" "' 2007 `" "Financial" "Crisis" "' 2013 `" "Per-Capita GDP" "Recovery" "' 2020 "Covid-19" , axis(2)) tline(2001 2007 2013 2020, lpattern(dot))

graph export output/NL_PCE_rexpenditures`elabel'`sample'`time'.png, replace



tsline asnr asnrH asnrL if year > 1990 , xaxis(1 2) xlabel(1992(4)2020, axis(1)) xtitle(Year, axis(1)) xtitle("",axis(2)) ytitle(Necessity Share) bgcolor(white) graphregion(color(white)) legend(off) lcolor( blue gray gray) lpattern(1 - -) xla(2001 `" "2001" "Recession" "' 2007 `" "Financial" "Crisis" "' 2013 `" "Per-Capita GDP" "Recovery" "' 2020 "Covid-19" , axis(2)) tline(2001 2007 2013 2020, lpattern(dot))

graph export output/rnecessity_share_wci`elabel'`sample'`time'.png, replace
	}
else{
	
	
	tsline Xn Xl if year > 1990, xaxis(1 2) xlabel(128(12)244, axis(1)) xtitle(Quarter, axis(1)) xtitle("",axis(2)) ytitle(Necessity Share) bgcolor(white) graphregion(color(white)) legend(off) lcolor( blue gray gray) lpattern(1 - -) xla( 164 `" "2001" "Recession" "' 191 `" "Financial" "Crisis" "' 214 `" "Per-Capita GDP" "Recovery" "' 240 "Covid-19" , axis(2)) tline(164 191 214 240, lpattern(dot))


graph export output/NL_PCE_expenditures`elabel'`sample'`time'.png, replace
	
	
tsline Xn Xl X if year > 1990, xaxis(1 2) xlabel(128(12)244, axis(1)) xtitle(Quarter, axis(1)) xtitle("",axis(2)) ytitle(Necessity Share) bgcolor(white) graphregion(color(white)) legend(off) lcolor( blue gray gray) lpattern(1 - -) xla( 164 `" "2001" "Recession" "' 191 `" "Financial" "Crisis" "' 214 `" "Per-Capita GDP" "Recovery" "' 240 "Covid-19" , axis(2)) tline(164 191 214 240, lpattern(dot))

graph export output/NL_PCE_expenditures`elabel'`sample'`time'_wtotal.png, replace

tsline Xnr Xlr if year > 1990, xaxis(1 2) xlabel(128(12)244, axis(1)) xtitle(Quarter, axis(1)) xtitle("",axis(2)) ytitle(Necessity Share) bgcolor(white) graphregion(color(white)) legend(off) lcolor( blue gray gray) lpattern(1 - -) xla( 164 `" "2001" "Recession" "' 191 `" "Financial" "Crisis" "' 214 `" "Per-Capita GDP" "Recovery" "' 240 "Covid-19" , axis(2)) tline(164 191 214 240, lpattern(dot))

graph export output/NL_PCE_rexpenditures`elabel'`sample'`time'.png, replace



tsline asnr asnrH asnrL if year > 1990, xaxis(1 2) xlabel(128(12)244, axis(1)) xtitle(Quarter, axis(1)) xtitle("",axis(2)) ytitle(Necessity Share) bgcolor(white) graphregion(color(white)) legend(off) lcolor( blue gray gray) lpattern(1 - -) xla( 164 `" "2001" "Recession" "' 191 `" "Financial" "Crisis" "' 214 `" "Per-Capita GDP" "Recovery" "' 240 "Covid-19" , axis(2)) tline(164 191 214 240, lpattern(dot))

graph export output/rnecessity_share_wci`elabel'`sample'`time'.png, replace
	
	
}
}
}
}
