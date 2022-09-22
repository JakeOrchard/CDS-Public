/**********************************************************************;
* Project           : Competing for necessities
*
* Program name      : reg_shares_UR
*
* Author            : Jacob Orchard 
*
* Date created      : 7/10/21
*
* Purpose           : Regresses prices on UR
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

*Merges data together
 use $CEX/clean_regression_vars.dta, clear



drop if CPICategory == ""
drop if CPIgroup == .



gen price_balance1 = year > 1986 
replace price_balance1 = 0 if value == .
bys CPIgroup price_balance1 : gen number1 = _N
sum number1
replace price_balance1 = 0 if number1 != r(max) //Balanced Price Panel 1987-2020



label var lprice "Log of CPI Index"

sort CPIgroup month



/******************************************************************************
2. Creates Regression Table
******************************************************************************/

*************For MAIN TEXT****************************
gen lshare_sa_smooth2 = lshare_sa_smooth

local depvariablelist `"lshare_sa_smooth" "lshare_sa_smooth2"'
local tablelist `"" "alt"'


foreach tableversion in "`tablelist'"{
foreach dep in "`depvariablelist'"{
	
	cap drop main_ind
	
	if "`dep'" == "lshare_sa_smooth"{
				    
		local title `"Panel A: Binary necessity good"'
		local filename `"table_shares_unrate_PA`tableversion'"'
		local depname `"Log-Share"'
			gen main_ind = unrate*necessity
				local indname "UR $\times$ Necessity"


	}
	
	else if "`dep'" == "lshare_sa_smooth2"{
		
		local title `"Panel B: Scale by expenditure ratio "'
		local filename `"table_shares_unrate_PB`tableversion'"'
		local depname `"Log-Share"'
			gen main_ind = unrate*ratio_total
				local indname "UR $\times$ Exp. Ratio"



		
	} 


	
	*FE BASELINE 
	ivreghdfe `dep' main_ind, absorb(month CPIgroup) bw(6) cluster(month)
	eststo
	qui estadd local sectorfe `"Yes"'
	qui estadd local monthfe `"Yes"'
	qui estadd local weight `"No"'


	*Weighted Regresssion
	ivreghdfe `dep' main_ind [w=stoneweight], absorb(month CPIgroup) bw(6) cluster(month)
	eststo
	qui estadd local sectorfe `"Yes"'
	qui estadd local monthfe `"Yes"'
	qui estadd local weight `"Yes"'



	*Addtional Controls
	ivreghdfe `dep' main_ind energy_int [w=stoneweight] , absorb(month CPIgroup) bw(6) cluster(month)
	eststo
	qui estadd local sectorfe `"Yes"'
	qui estadd local monthfe `"Yes"'
qui estadd local weight `"Yes"'
	
	ivreghdfe `dep' main_ind durable_int [w=stoneweight] , absorb(month CPIgroup) bw(6) cluster(month)
	eststo
	qui estadd local sectorfe `"Yes"'
	qui estadd local monthfe `"Yes"'
qui estadd local weight `"Yes"'
	
	ivreghdfe `dep' main_ind service_int [w=stoneweight], absorb(month CPIgroup) bw(6) cluster(month)
	eststo
	qui estadd local sectorfe `"Yes"'
	qui estadd local monthfe `"Yes"'
	qui estadd local weight `"Yes"'
	
		if "`tableversion'" == "alt"{
	ivreghdfe `dep' main_ind work_int [w=stoneweight], absorb(month CPIgroup) bw(6) cluster(month)
	eststo
	qui estadd local sectorfe `"Yes"'
	qui estadd local monthfe `"Yes"'
	qui estadd local weight `"Yes"'
		}
	

	
/******************************************************************************
Export Regression Table
*******************************************************************************/
		if "`tableversion'" == ""{
		local nregs = 5
		local keepvars `"main_ind energy_int durable_int service_int"'
		local order `"main_ind energy_int durable_int service_int"'
		local tableformat "lXXXXX"
		}
		if "`tableversion'" == "alt"{
			local nregs = 6
			local keepvars `"main_ind energy_int durable_int service_int work_int"'
			local order `"main_ind energy_int durable_int service_int work_int"'
			local tableformat "lXXXXXX"

			}
					local nregs1 = `nregs'+1

		local indicate
		local groups1 `"& \multicolumn{`nregs'}{c}{} \\"'

		local stype `" & \multicolumn{`nregs'}{c}{`depname'}"'
		local lower `" `stype'   \\  "'
		local groups `" "`groups1'   `lower' "  "'

		local stats "sectorfe monthfe weight   N"
		local stats_fmt " %3s %12.2f %12.0fc"
		local stats_label `" `"Sector FE"'  `"Month FE"'  `"Weighted"' `"Observations"' "'
		local num_stats: word count `stats'

		local layout
		forvalues l = 1/`num_stats' {
			local layout `"`layout' "\multicolumn{1}{c}{@}" "'
		}
		local dropvars 
		local table_preamble `" "\begin{table}[!t] \centering \sisetup{table-format=1.2} \def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}"    "\label{table:share_unrate}""\begin{tabularx}{\textwidth}{`tableformat'}" "\\" "\hline\hline" "'
		local prehead `"prehead(`table_preamble' `groups')"'			
		local posthead `"posthead(`"\hline"' `"\multicolumn{`=`nregs'+1'}{l}{Right hand side variables:}\\"' `"\\"')"'
		
		local notes `"Notes: The unit of observation is the sector-month. Exp. ratio is the ratio of expenditure shares of poor over rich households for the sector. Standard errors, in parentheses, are clustered at the time level and are robust to auto-correlation. Significance at the 1, 5, and 10 percent levels indicated by ***,**, and *. Share is defined as the aggregate expenditure on sector j divided by total aggregate expenditure."'
		local prefoot(" ")
		local postfoot `"postfoot(`"\hline\hline \end{tabularx} \begin{minipage}{\hsize} \rule{0pt}{9pt} \tiny `notes'  \end{minipage} \label{tab:`filename'} \end{table}"')"'
		*This first one produces tables for the presentation (panel A and b are self contained)
		
		esttab * using "$output/`filename'_presentation.tex",  replace cells(b(star fmt(%9.3f)) se(par fmt(a2) abs)) starlevels( \$^{*}$ 0.1 \$^{**}$ 0.05 \$^{***}$ 0.01  ) drop(`dropvars', relax) keep(`keepvars') indicate(`indicate') `prehead' `posthead' `postfoot' order(`order') label coeflabels( main_ind "`indname'" energy_int "UR $\times$ Energy" durable_int "UR $\times$ Durable" service_int "UR $\times$ Service"  work_int "UR $\times$ Work Related") stats(`stats', layout(`layout') fmt(`stats_fmt') labels(`stats_label')) collabels(,none) numbers nomtitles substitute(# `" X "' tabular* tabularx `"{1}{c}{("' `"{1}{L}{("') width(\hsize)
		
	*This produces tables for the paper (panel A and B in one table)
	if "`dep'" == "lshare_sa_smooth"{
	local table_preamble `" "\begin{table}[!t] \centering \sisetup{table-format=1.2} \def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" "\caption{Relationship Unemployment and Relative Necessity Shares}"   "\label{table:share_unrate}" "\begin{tabularx}{\textwidth}{`tableformat'}" "\toprule     \multicolumn{`nregs1'}{l}{\textbf{`title'}} \\ \midrule" "'
		local prehead `"prehead(`table_preamble' `groups')"'			   
		local postfoot `"postfoot(`"\hline\hline \end{tabularx}"')"' 
	}
	
	else if "`dep'" == "lshare_sa_smooth2"{
		local table_preamble `" "\begin{tabularx}{\textwidth}{`tableformat'}" "\toprule     \multicolumn{`nregs1'}{l}{\textbf{`title'}} \\ \midrule" "'
		local prehead `"prehead(`table_preamble' `groups')"'
		local postfoot `"postfoot(`"\hline\hline \end{tabularx} \begin{minipage}{\hsize} \rule{0pt}{9pt} \footnotesize `notes'  \end{minipage} \label{tab:`filename'} \end{table}"')"'
		
	}
	
	esttab * using "$output/`filename'_paper.tex",  replace cells(b(star fmt(%9.3f)) se(par fmt(%9.3f) abs)) starlevels( \$^{*}$ 0.1 \$^{**}$ 0.05 \$^{***}$ 0.01  )  drop(`dropvars', relax) keep(`keepvars') indicate(`indicate') `prehead' `posthead' `postfoot' order(`order') label coeflabels( main_ind "`indname'" energy_int "UR $\times$ Energy" durable_int "UR $\times$ Durable" service_int "UR $\times$ Service"  work_int "UR $\times$ Work Related") stats(`stats', layout(`layout') fmt(`stats_fmt') labels(`stats_label')) collabels(,none) numbers nomtitles substitute(# `" X "' tabular* tabularx `"{1}{c}{("' `"{1}{L}{("') width(\hsize)
	
			estimates drop _all

}


	}

















/**********************************Additional Regressions***************************



	*Simplest
	reg lprice  c.unrate##c.ratio_total, robust
	

*Baseline
ivreghdfe lprice c.unrate##c.ratio_total, absorb(month CPIgroup) bw(6) cluster(month)

*Balanced Sample
reg lprice c.unrate##c.ratio_total if balance1967 == 1

reg lprice c.unrate##c.ratio_total if balance1977 == 1

reg lprice c.unrate##c.ratio_total if balance1987 == 1

reg lprice c.unrate##c.ratio_total if balance1997 == 1

ivreghdfe lprice c.unrate##c.ratio_total if balance1997==1, absorb(month CPIgroup) bw(6) cluster(month)


*Weighted Regresssion

reg lprice c.unrate##c.ratio_total [w=stoneweight] if balance1987 == 1

ivreghdfe lprice c.unrate##c.ratio_total [w=stoneweight], absorb(month CPIgroup) bw(6) cluster(month)

ivreghdfe lprice c.unrate##c.ratio_total [w=stoneweight] if balance1987==1, absorb(month CPIgroup) bw(6) cluster(month)


*FE Regression

reghdfe lprice c.unrate##c.ratio_total , absorb(CPIgroup)

reghdfe lprice c.unrate##c.ratio_total , absorb(CPIgroup month)

reghdfe lprice c.unrate##c.ratio_total  [w=stoneweight], absorb(CPIgroup)

reghdfe lprice c.unrate##c.ratio_total  [w=stoneweight], absorb(CPIgroup month)

*Additional interaction controls

reg lprice c.unrate##c.ratio_total c.unrate##energy

reg lprice c.unrate##c.ratio_total c.unrate##durable

reg lprice c.unrate##c.ratio_total c.unrate##energy c.unrate##durable

*Everything
ivreghdfe lprice necessity_int energy_int durable_int [w=stoneweight] , absorb(month CPIgroup) bw(6) cluster(month)


