/**********************************************************************;
* Project           : Heterogeneous Inflation
*
* Program name      : Step_4_CPI_import_prices.do
*
* Author            : Jacob Orchard 
*
* Date created      : 10/19/2020
*
* Purpose           : Creates income group inflation measures based on expenditure weights. NOTE: THIS REQUIRES PYTHON 3 TO RUN.
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* 
**********************************************************************/

clear all




/******************************************************************************
1. Creates list of Series ID for BLS API
*******************************************************************************/


use "$CEX/cpi_categories.dta", clear


keep CPICode
keep if CPICode != "house"

export delimited using $CEX/seriesid.csv, replace


/******************************************************************************
2. Runs Python Code that interacts with BLS API
*******************************************************************************/

!python code/python/step4b_pullcpi.py


/******************************************************************************
3. Imports and cleans data
*******************************************************************************/



forval i = 0/117{

tempfile t`i'

di `i'

insheet using "$CPI/seriesprices_na_`i'.csv", clear
drop v1
save	`t`i''
}

use `t0', clear
forval i = 1/117{
	append using `t`i''
}

sort cpicode year period
duplicates drop 

gen monthnumber = substr(period,2,2)

destring monthnumber, replace
gen month = ym(year,monthnumber)
format month %tm

drop monthnumber period

rename cpicode CPICode

merge m:1 CPICode using $CEX/cpi_categories.dta

drop _merge

label data "Sector level prices: Step_4_CPI_import_prices.do 10.22.2020"

save $CPI/sector_prices.dta, replace





