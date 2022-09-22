/**********************************************************************;
* Project           : Heterogeneous Inflation
*
* Program name      : Monetary_Elasticity_IRF_monthly.do
*
* Author            : Jacob Orchard 
*
* Date created      : 3/23/2021
*
* Purpose           : Creates IRF of monetary policy semi-elasticity of prices and shares at the monthly level for necessities versus luxuries
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* 5/26/21      Orchard           Added interaction between durable and monetary shock
**********************************************************************/

clear all



/****************************************************************************
1. Prep Data
*****************************************************************************/


*Monthly Shock Data


*High Frequency with FOMC annourcments and meetings
import excel "$rawdata/FOMC_Bauer_Swanson.xlsx", sheet("FOMC_Announcements") firstrow clear

gen month = mofd(Date)
format month %tm
drop if month == .

*Drop annoucment after Sep. 11 2001
drop if Date == date("17sep2001","DMY")

destring MPS MPS_ORTH, replace

collapse (sum) MPS MPS_ORTH, by(month)

save $temp/swanson_extended_month.dta, replace


*Pooled Aggregate share
tempfile aggshare
use $CEX/aggregate_shares.dta, clear

collapse (mean) agg_share, by(CPICategory)
save `aggshare'

*Merges data together
 use $CEX/clean_regression_vars.dta, clear


merge m:1 CPICategory using `aggshare', nogen

drop if CPICategory == ""
drop if CPIgroup == .



gen price_balance1 = year > 1986 
replace price_balance1 = 0 if value == .
bys CPIgroup price_balance1 : gen number1 = _N
replace number1 = 0 if price_balance1 != 1
sum number1
replace price_balance1 = 0 if number1 != r(max) //Balanced Price Panel 1987-2020



label var lprice "Log of CPI Index"

sort CPIgroup month


merge m:1 month using $temp/swanson_extended_month.dta, nogen

xtset CPIgroup month

sort CPIgroup month


egen onecat = tag(month)



/******************************************************************************
2. Standardizes shock to 25 basis points
******************************************************************************/

*Replaces missing values with zero
replace MPS = 0 if MPS == . & (month > ym(1988,1) & month < ym(2020,1) )
replace MPS_ORTH = 0 if MPS_ORTH == . & (month > ym(1988,1) & month < ym(2020,1) )


 *Treasury Bill
 preserve 

 collapse (mean)  MPS*  dgs1 lpce lrX unrate pcepi cpi monthnum  ,by(month)
 
 tsset month
 gen year = yofd(dofm(month))
  
 
 **IRF**
cap drop ttq
gen ttq = _n-1

sort month
tsset month




foreach shock in  MPS MPS_ORTH{

capture drop `shock'_coef
gen `shock'_coef=.
capture drop `shock'_se
gen `shock'_se=.


	  
reg dgs1 l(1/12).dgs1  `shock' l(1/20).`shock'  l(1/12).unrate l(1/12).cpi 
replace `shock'_coef=_b[`shock'] if ttq ==0
replace `shock'_se=_se[`shock'] if ttq ==0

cap drop `shock'unit 
 cap drop unit_`shock'
 gen `shock'unit = .25/`shock'_coef if ttq==0
 egen unit_`shock' = max(`shock'unit)
 
 gen norm_`shock' = `shock'/unit_`shock'
	 

}


	
/******************************************************************************
4. Consumption Interest rate elasticity IRF
******************************************************************************/

*Creates frame with results


local depvariablelist `"lpce" "lrX" "dgs1"'

local shocklist `"MPS" "MPS_ORTH"'


foreach dep in "`depvariablelist'"{

		foreach shock in  "`shocklist'"{

		cap drop horizon
		gen horizon = _n-1
		cap drop a_coef 
		cap drop a_se
		gen a_coef = .
		gen a_se = .


		forval h = 0/48{
			cap drop depvar	  
			gen depvar = f`h'.`dep'
				
					
			quiet ivreg2 depvar l(1/12).`dep' i.monthnum   norm_`shock' l(1/12).norm_`shock' l(1/12).dgs1 l(1/12).unrate l(1/12).cpi, robust

			replace a_coef = _b[norm_`shock'] if horizon == `h'
			replace a_se = _se[norm_`shock'] if horizon == `h'
	}
						


		cap drop a_low a_high a_low2 a_high2
		gen a_low = a_coef - a_se
		gen a_high = a_coef + a_se
		gen a_low2 = a_coef - 2*a_se
		gen a_high2 = a_coef + 2*a_se
		
		
		***Export Graph***
		
		if "`dep'" == "lpce"{
		local depname "Log-Consumption"
		}
		
		if "`dep'" == "lrX"{
		local depname "Log-Real Consumption"
		}
		
		if "`dep'" == "dgs1"{
		local depname "Interest Rate"
		}

		local title `"Monetary Policy Semi-Elasticity of  `depname' "'
			
		local filename `"IRF_`dep'_elasticity_`shock'"'


		
		set scheme s2color
		colorpalette economist, select(1/15) nograph
		#delimit
		twoway (line a_coef horizon if horizon <=48, color(navy) lpattern("-") )
		||
		(rarea a_low a_high horizon if horizon <= 48, color(edkblue%70) ) ||
		(rarea a_low2 a_high2 horizon if horizon <= 48, color(edkblue%30) ) 

		,

		  ytitle("`depname'") xtitle("Month Since Shock")
		 name(irf, replace) xlabel(0(6)48) 
		  graphregion(color(white)) bgcolor(white) legend(off) ;
		 #delimit cr;
	 
		graph export "output/`filename'.png", replace

		if "`shock'" == "FederalFundsRatefactor"{
		rename a_coef 	`dep'_coef
		rename a_low 	`dep'_low
		rename a_high 	`dep'_high

			frame put `dep'_coef horizon `dep'_high `dep'_low, into(results_`dep')
		}
		}
	}
sort month
keep month monthnum lpce lrX dgs1 unrate cpi norm_* 
order month monthnum norm_* lpce lrX dgs1 unrate cpi 	
keep if month > ym(1988,1) & month < ym(2020,1)
export delimited output/monetaryshock_series.csv, replace

tempfile norm
keep month norm_*
save `norm'
 restore
 
***Prices

merge m:1 month using `norm', nogen



egen cpigroup2 = group(CPIgroup)


sort cpigroup2 month
xtset cpigroup2 month





/******************************************************************************
3. Monetary Policy Elasticity IRF
******************************************************************************/

*Sector specific time trends
sum month if Federal != .
gen timetrend = month - r(min)

gen insample = cpigroup2 != .


rename lshare_sa_smooth ls
rename lrcost_sa_smooth lr
rename price_balance1 balanced
gen nonbalanced = 1

local depvariablelist `"lprice"  "ls"  "lr"'

local indvariablelist `"ratio_total" "necessity"'
local weightlist `"[w=stoneweight]" ""'
local balancelist `"balanced" "nonbalanced"'
local morecontrols `"eng_ind service_ind durable_ind"'
local morelaglist `"lag_int"'
local timelist `"" "& month <ym(2008,12)"'
local shocklist `"MPS_ORTH"'





quiet foreach shock in "`shocklist'"{
foreach ind in "`indvariablelist'"{
cap drop durable_ind eng_ind service_ind	
gen durable_ind = norm_`shock'*durable
gen eng_ind = norm_`shock'*energy
gen service_ind = norm_`shock'*service


foreach dep in "`depvariablelist'"{
		cap drop baseline

	foreach balance in "`balancelist'"{
		foreach time in "`timelist'"{
	
	
	if "`dep'" == "lprice"{
	local depname "Log-Price"
	local depname2 "Sector Prices"
	local addendum ""
	}
	if "`dep'" == "ls"{
	if "`balance'" == "balanced"{	
		continue
	}
	local depname "Log-Share"
	local depname2 "Relative Demand"
	local addendum ""
	}
	
	if "`dep'" == "lr"{
	local depname "Log-Real Expenditure"
	local depname2 "Relative Demand"
	local addendum ""
	}
	

	
				eststo clear
				cap drop main_ind
				gen main_ind = norm_`shock'*`ind'
				
				
		foreach weight in "`weightlist'"{
			eststo clear
			
			    eststo clear
			
			foreach morlag in "`morelaglist'"{
			foreach morec in "`morecontrols'"{
					local morelags ""
				
					if "`morlag'" == "lag_int"{
						if "`morec'" == "durable_ind"{
						local morelags l(1/12).main_ind l(1/12).durable_ind
						local goodname "durable_ind"
						local goodtitle "with durables control"
			
						}
						if "`morec'" == "service_ind"{
						local morelags l(1/12).main_ind l(1/12).service_ind
						local goodname "service_ind"
						local goodtitle "with service control"

						}
						if "`morec'" == "eng_ind"{
						local morelags l(1/12).main_ind l(1/12).eng_ind
						local goodname "eng_ind"
						local goodtitle "with energy control"

						}
						if "`morec'" == "eng_ind durable_ind"{
						local morelags l(1/12).main_ind l(1/12).eng_ind l(1/12).durable_ind
						local goodname "engdur_ind"
						local goodtitle "with additional controls"

						}
						if "`morec'" == "eng_ind service_ind"{
						local morelags l(1/12).main_ind l(1/12).eng_ind l(1/12).service_ind
						local goodname "engserv_ind"
						local goodtitle "with additional controls"

						}
						if "`morec'" == "eng_ind service_ind durable_ind"{
						local morelags l(1/12).main_ind l(1/12).eng_ind l(1/12).durable_ind l(1/12).service_ind
						local goodname "multiple_ind"
						local goodtitle ""

						}
						if "`morec'" == "eng_ind service_ind durable_ind i.cpigroup2#c.timetrend"{
						local morelags l(1/12).main_ind l(1/12).eng_ind l(1/12).durable_ind l(1/12).service_ind
						local goodname "multiple_ind_timetrend"
						local goodtitle ""

						}
						if "`morec'" == "" {
						local morelags l(1/12).main_ind

						}
						if "`morec'" == "i.cpigroup2#c.timetrend"{
							continue
						}

						local lagname "iR_lag"
						
					}
					
			if "`morlag'" == ""{
				local morelags ""
				local lagname ""
			}
			    
			cap drop horizon
			gen horizon = _n-1
			cap drop a_coef
			cap drop a_se
			gen a_coef = .
			gen a_se = .
				
				
				forval h = 0/48{
			cap drop depvar	  
			gen depvar = f`h'.`dep'
			noi di "`dep'" "`ind'" "`morec'" "`morelags'" "`h'" "`balance'" "`weight'" "`time'" 
	
				
				 quiet ivreghdfe depvar l(1/12).ls l(1/12).lprice main_ind `morelags'   `morec'  `weight'   if insample & `balance' `time',  cluster(month) absorb( month cpigroup2) bw(4)
				 *Lag length = round(T^(1/4)) see Greene (Econometric Analysis 7th edition)
				 *T = 196 for 2008 sample

				
				replace a_coef = _b[main_ind] if horizon == `h'
				replace a_se = _se[main_ind] if horizon == `h'
				}
					
			

				cap drop a_low a_high a_low2 a_high2
				*gen a_low = a_coef - 1.282*a_se
				*gen a_high = a_coef + 1.282*a_se
				gen a_low = a_coef - a_se
				gen a_high = a_coef + a_se
				gen a_low2 = a_coef - 2*a_se
				gen a_high2 = a_coef + 2*a_se
		 



		***********Export Graph************************************

		if "`weight'" == "[w=stoneweight]"{
			
			local weightname ""
			local addtitle " weighted by aggregate share"
		}

		else if "`weight'" == ""{
			
			local weightname "nonweighted_"
			local addtitle ""
		}
		
		
		if "`time'" == ""{
			
			local timename ""
		}

		else if "`time'" != ""{
			
			local timename "pre2008"
		}
		
		
		
		
		
		
		local baseline "no"

		if "`morec'" == "eng_ind service_ind durable_ind"  & "`morlag'" == "lag_int" & "`balance'" == "balanced" & "`time'" == "" & "`weight'" == "[w=stoneweight]"{
			
			local goodname ""
			local goodtitle ""
		    
			cap drop baseline
			gen baseline = a_coef
			local baseline "yes"

			
		}
		
		if "`morec'" == "eng_ind service_ind durable_ind"  & "`morlag'" == "lag_int" & "`balance'" == "nonbalanced" & "`dep'" == "ls" & "`time'" == "" & "`weight'" == "[w=stoneweight]"{
			
			local goodname ""
			local goodtitle ""
		    
			cap drop baseline
			gen baseline = a_coef
			local baseline "yes"
			
		}
		
		if "`morec'" == "i.cpigroup2#c.timetrend"{
				local goodname "timetrend"
			local goodtitle "with time trends"
						}
						
			if "`morec'" == ""{
		    
			local goodname ""
			local goodtitle ""
			
		}
		
		
		
			

		local title `"Monetary Policy Semi-Elasticity of  `depname2' `goodtitle' `balance' `addtitle' `addendum'"'
		
		local filename `"IRF_`dep'_elasticity_`goodname'_`weightname'`balance'`ind'_`shock'`lagname'`timename'"'


if "`baseline'" == "no"{

	set scheme s2color
		colorpalette economist, select(1/15) nograph
#delimit
twoway (line a_coef horizon if horizon <=48, color(navy)  )
||
(line baseline horizon if horizon <=48, color(cranberry) lpattern("-x") )
||
(rarea a_low a_high horizon if horizon <= 48, color(edkblue%70) ) ||
(rarea a_low2 a_high2 horizon if horizon <= 48, color(edkblue%30) ) 

,

  ytitle("`indname' `goodtitle'") xtitle("Month Since Shock")
 name(irf, replace) xlabel(0(6)48) 
  graphregion(color(white)) bgcolor(white) legend( order(1 "Modified Version" 2 "Baseline")) ;
 #delimit cr;
 
 	noi graph export "output/`filename'.png", replace
}


else if "`baseline'" == "yes"{
	set scheme s2color
		colorpalette economist, select(1/15) nograph
#delimit
twoway (line a_coef horizon if horizon <=48, color(navy) )
||
(rarea a_low a_high horizon if horizon <= 48, color(edkblue%70) ) ||
(rarea a_low2 a_high2 horizon if horizon <= 48, color(edkblue%30) ) 
,
  ytitle("`indname' `goodtitle'") xtitle("Month Since Shock")
 name(irf, replace) xlabel(0(6)48) 
  graphregion(color(white)) bgcolor(white) legend(off) ;
 #delimit cr;
 
 	noi graph export "output/`filename'.png", replace
		if "`time'" == "" & "`shock'" == "FederalFundsRatefactor" {

	foreach var in coef low low2 high high2{
		rename a_`var' `dep'`ind'_`var'
		
	}
	
		frame put `dep'`ind'_* horizon, into(results_`ind'`dep'`lagname')
		}
	
}

if "`morec'" == "eng_ind" & "`morlag'" == "" {
	
		if "`time'" == "" & "`shock'" == "FederalFundsRatefactor"{
	foreach var in coef low low2 high high2{
		rename a_`var' `dep'E`ind'`lagname'_`var'
		
	}
		
		frame put `dep'E`ind'`lagname'_* horizon, into(results_`ind'`dep'E)
		}
}
		
		}
		}
		}
		}
		
		}
	
		

	}
}	
}

