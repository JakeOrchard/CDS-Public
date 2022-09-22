/**********************************************************************;
* Project           : Heterogeneous Inflation
*
* Program name      : CEX_2_hhspend_v2.do
*
* Author            : Jacob Orchard 
*
* Date created      : 04/23/2020
*
* Purpose           : Creates expenditure weights based on MTBI CEX files
*s
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* 
*9.29.2020                       Fixed Food expenditures based on UCC Hierarchy
*7.22.21                         Also creates data based on month of interview
**********************************************************************/

clear all


local yearmin = 1990 //First year of mtbi files
local yearmax = 2020
local yearmaxp1 = `yearmax'+1




/******************************************************************************
1. Pulls in CEX and CPI crosswalk. 
*******************************************************************************/

import excel "$rawdata/CEX_CPI_crosswalk.xlsx", sheet("Sheet1") cellrange(A3:O676) firstrow clear

drop H I  

replace CPICategory = CPICategory[_n-1] if CPICategory == ""
replace CPICodenot = CPICodenot[_n-1] if CPICodenot == ""
replace CPICodeseas = CPICodeseas[_n-1] if CPICodeseas =="" & CPICategory == CPICategory[_n-1]

replace Durable = Durable[_n-1] if Durable == .
replace Oil = Oil[_n-1] if Oil == .
replace Service = Service[_n-1] if Service == .
replace Transportation = Transportation[_n-1] if Transportation == .
replace Work = Work[_n-1] if Work == .

drop if CUCode == .
rename CUCode ucc

drop FMLI*

save $CEX/CEX_CPI_crosswalk.dta, replace

collapse (mean) Durable Oil Service Transportation Work, by(CPICategory)

rename Durable durable
rename Oil oil
rename Service service
rename Transportation transportation
rename Work work
save $CEX/CEX_durable.dta, replace


/******************************************************************************
2. Extracts and Cleans raw MTBI data
******************************************************************************/


forval year=`yearmin'(1)`yearmax' {
	local yy2 = substr("`year'",3,2)
	disp "`yy2'"
	
	forval i=1/4{
		
		
		if `year' >1995 & `i'==1{
		exit
		}
	
		if `year' != 2017 & `year' != 1999 & `year' != 1994 &`year'!=1995		&`year'!= 1997 & `year'!=1998 & `year' != 2001 & `year' ~= 2019 & `year' ~= 1992  & `year' ~= 1993{
			use $temp/intrvw`yy2'/mtbi`yy2'`i'.dta, clear
			}
			
		if `year' == 2017| `year' == 1998 | `year'==1997 | `year' == 1994 |`year' ==1995 | `year' ==2001 | `year' == 2019{
		 use $temp/intrvw`yy2'/intrvw`yy2'/mtbi`yy2'`i'.dta, clear
		
		}
		
		if `year' == 1999 |`year' == 1992 |`year' == 1993 {
		use $temp/mtbi`yy2'`i'.dta, clear

		}
		
	
	
		collapse (sum) cost, by(ucc  newid)

				
		gen year = `year'
		gen qtrnum = `i'
		
		
		
			
		destring newid, replace
		gen newid_ = newid
		tostring newid, replace
		gen cuid = substr(newid, 1, 6) if newid_ >= 1000000
		replace cuid = substr(newid, 1, 5) if newid_ < 1000000
		drop newid_
		quietly destring newid cuid ucc, replace		
		
			merge m:1 ucc using $CEX/CEX_CPI_crosswalk
			
		replace CPICategory = "Housing" if CPICategory == "Owner's equivalent rent of residences" | CPICategory == "Rent of Primary Residence"

		replace CPICodenot = "house" if CPICategory == "Housing"
		replace CPICodeseas = "house" if CPICategory == "Housing"

	collapse (sum) cost, by(year qtrnum cuid newid CPICategory CPICodenot CPICodeseas)
			save "$temp/mtbi_`year'`i'.dta", replace
		
		}
}

*Pulls in first quarter interview. I use the 1x interview series for all years so the questions match those in the rest of the year,
	*with the exception of 1996, 2005, and 2015 where I use the 1 series. The 1x series for these three years do not have any January interviews.
	

forval year=1996(1)`yearmaxp1' {
	
	local pyear = `year'-1
	local yy2 = substr("`year'",3,2)
	local pyy2 = substr("`pyear'",3,2)

	noi disp "`yy2'"
		
		if `year' != 2017 & `year' != 1999 & `year' != 1996 & `year' != 2005 & `year' != 2015  & `year' != 1994 &`year'!=1995		&`year'!= 1997 & `year'!=1998 & `year' != 2001 & `year' ~= 2019 & `year' ~= 2020 & `year' ~= 2021{
			use $temp/intrvw`yy2'/mtbi`yy2'1x.dta, clear
			}
			
		if `year' == 2017| `year' == 1998 | `year'==1997 | `year' == 1994 |`year' ==1995 |`year' ==2001 | `year' == 2019{
		 use $temp/intrvw`yy2'/intrvw`yy2'/mtbi`yy2'1x.dta, clear
		}
		
		if `year' == 1999{
		use $temp/mtbi`yy2'1x.dta, clear

		}
		if `year' == 1996{
	 use $temp/intrvw`pyy2'/intrvw`pyy2'/mtbi`yy2'1.dta, clear
	}	
	
	if `year' == 2005 | `year' == 2015 | `year' == 2021{
	use $temp/intrvw`pyy2'/mtbi`yy2'1, clear	
	}	
	
	if `year' == 2020{
	use $temp/intrvw`pyy2'/intrvw`pyy2'/mtbi`yy2'1, clear	
	}	
	
	
	collapse (sum) cost, by(ucc  newid)

		gen year = `year'
		gen qtrnum = 1
			
	destring newid, replace
	gen newid_ = newid
	tostring newid, replace
	gen cuid = substr(newid, 1, 6) if newid_ >= 1000000
	replace cuid = substr(newid, 1, 5) if newid_ < 1000000
	drop newid_
	quietly destring newid cuid ucc , replace	
	
	merge m:1 ucc using $CEX/CEX_CPI_crosswalk
	
	replace CPICategory = "Housing" if CPICategory == "Owner's equivalent rent of residences" | CPICategory == "Rent of Primary Residence"
	
	replace CPICodenot = "house" if CPICategory == "Housing"
		replace CPICodeseas = "house" if CPICategory == "Housing"
	
	
	collapse (sum) cost, by(year qtrnum cuid newid CPICategory CPICodenot CPICodeseas)
	
		save "$temp/mtbi_`year'1.dta", replace
		

		
}



/******************************************************************************
2. Appends data files and saves
******************************************************************************/


clear
set obs 1
gen blank = .

forval year=`yearmin'(1)`yearmaxp1' {
	disp `year'
	forval i=1/4{
		
		if `i' > 1 & `year' == `yearmaxp1'{
			
		
		}
		else{
		append using $temp/mtbi_`year'`i'.dta
		}
		}
	}
		
drop blank
drop if cuid == .


label data "Clean MTBI Files: Step_2_CEX_hhspend.do  7.22.21"

save $CEX/clean_mtbi.dta, replace





*Cleans temp directory
!rmdir $temp  /s /q
cap mkdir $temp
