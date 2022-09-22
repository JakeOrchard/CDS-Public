/**********************************************************************;
* Project           : Heterogeneous Inflation
*
* Program name      : CEX_1_hhinfo.do
*
* Author            : Jacob Orchard
*
* Date created      : 04/15/2019
*
* Purpose           : Creates unique hh_id for all households. Saves pertinent
                      demographic information for each household.
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* 5.13.20     Jacob Orchard          Added pre 2013 info
* 1.14.21     J. Orchard            Added interview month
**********************************************************************/

clear all


local yearmin = 1990
local yearmax = 2020
local yearmaxp1 = `yearmax'+1




/******************************************************************************
1. Variale list for each year
******************************************************************************/

global varlist_1318 newid cuid finlwt21 hhid liqudyrx liquidx creditb creditx credtyrx irax irayrx num_auto num_tvan othastx othfinx othlnyrx othlonx othstyrx owndwecq othvehcq stdntyrx stockx stockyrx studntx vehq  whlfyrx wholifx  finatxem fincbtax fincbtxm  inc_rnkm intrdvx etotacx4 etotalc etotalp totex4cq  totex4pq totexpcq totexppq age_ref age2 educ_ref educa2 fam_size fam_type high_edu hisp_ref horref1 horref2 marital1 perslt18 persot64 popsize race2 ref_race region sex_ref no_earnr bls_urbn lumpsumx healthcq healthpq retpencq retpenpq lifinscq lifinspq cashcocq cashcopq  misccq miscpq qintrvmo qintrvyr renteqvx rendwecq rendwepq



global varlist_9501 newid  finlwt21 hhid   ckbkactx compckgx compowdx compsavx compsecx num_auto  owndwecq othvehcq savacctx secestx usbndx vehq fincatax  fincbtax    totexppq totexpcq totex4cq age_ref age2 educ_ref educa2 fam_size fam_type  marital1 perslt18 persot64 popsize race2 ref_race region sex_ref no_earnr bls_urbn lumpsumx cshcntbx healthcq healthpq retpencq retpenpq lifinscq lifinspq cashcocq cashcopq  misccq miscpq qintrvmo qintrvyr renteqvx rendwecq rendwepq



global varlist_0213 newid  finlwt21 hhid   ckbkactx compckgx compowdx compsavx compsecx num_auto  owndwecq othvehcq savacctx secestx usbndx vehq fincatax  fincbtax    totexppq totexpcq totex4cq age_ref age2 educ_ref educa2 fam_size fam_type  marital1 perslt18 persot64 popsize race2 ref_race region sex_ref no_earnr bls_urbn lumpsumx healthcq healthpq retpencq retpenpq lifinscq lifinspq cashcocq cashcopq  misccq miscpq qintrvmo qintrvyr renteqvx rendwecq rendwepq renteqvx rendwecq rendwepq





global varlist_0405 newid cuid  finlwt21 hhid   ckbkactx compckgx compowdx compsavx compsecx num_auto  owndwecq othvehcq savacctx secestx usbndx vehq fincatxm fincbtxm    totexppq totexpcq totex4cq age_ref age2 educ_ref educa2 fam_size fam_type  marital1 perslt18 persot64 popsize race2 ref_race region sex_ref no_earnr bls_urbn lumpsumx healthcq healthpq retpencq retpenpq lifinscq lifinspq cashcocq cashcopq  misccq miscpq qintrvmo qintrvyr renteqvx rendwecq rendwepq renteqvx rendwecq rendwepq





global varlist_9094 newid  finlwt21  ckbkactx compckgx compowdx compsavx compsecx usbndx savacctx owndwecq othvehcq savacctx fincatax fincbtax erank totexppq totexpcq age_ref age2 educ_ref fam_size fam_type marital1 perslt18 persot64 popsize race2 ref_race region sex_ref no_earnr bls_urbn lumpsumx  cshcntbx healthcq healthpq retpencq retpenpq lifinscq lifinspq cashcocq cashcopq  misccq miscpq qintrvmo qintrvyr 





/******************************************************************************
2. Pulls in data from raw fmli files
******************************************************************************/



set obs 1
gen blank = .

quietly forval year=`yearmin'(1)`yearmax' {
	local yy2 = substr("`year'",3,2)
	noi disp "`yy2'"
	
	forval i=1/4{
		
		
		if `year' >1995 & `i'==1{
		exit
		}
	
		if `year' != 2017 & `year' != 1999 & `year' != 1994 &`year'!=1995		&`year'!= 1997 & `year'!=1998 & `year' != 2001 & `year' ~= 2019 & `year' ~= 1992  & `year' ~= 1993  {
		use $temp/intrvw`yy2'/fmli`yy2'`i'.dta, clear
		}
		
	if `year' == 2017| `year' == 1998 | `year'==1997 | `year' == 1994 |`year' ==1995 | `year' ==2001 | `year' == 2019{
	 use $temp/intrvw`yy2'/intrvw`yy2'/fmli`yy2'`i'.dta, clear
	}
	
	if `year' == 1999 |`year' == 1992 |`year' == 1993  {
		use $temp/fmli`yy2'`i'.dta, clear

		}
		
		if `year' < 1995{
		keep $varlist_9094
			cap destring newid, replace
			gen newid_ = newid
			tostring newid, replace
			gen cuid = substr(newid, 1, 6) if newid_ >= 1000000
			replace cuid = substr(newid, 1, 5) if newid_ < 1000000
			drop newid_
			gen year = `year'
			gen qtrnum = `i'		
		
		}
		
		if (`year' > 1994 & `year' < 2001) {
			keep $varlist_9501
			cap destring newid, replace
			gen newid_ = newid
			tostring newid, replace
			gen cuid = substr(newid, 1, 6) if newid_ >= 1000000
			replace cuid = substr(newid, 1, 5) if newid_ < 1000000
			drop newid_
			gen year = `year'
			gen qtrnum = `i'
		
		}
		
		if (`year' > 2000 & `year' < 2004) | (`year' < 2013 & `year'>2005){
			keep $varlist_0213
			cap destring newid, replace
			gen newid_ = newid
			tostring newid, replace
			gen cuid = substr(newid, 1, 6) if newid_ >= 1000000
			replace cuid = substr(newid, 1, 5) if newid_ < 1000000
			drop newid_
			gen year = `year'
			gen qtrnum = `i'
		
		}
		
		if `year' > 2003 & `year' < 2006{
			keep $varlist_0405
			gen year = `year'
			gen qtrnum = `i'
			cap tostring newid, replace
		
		}
	
		if `year'>2012{
			keep $varlist_1318
			gen year = `year'
			gen qtrnum = `i'
			cap tostring newid, replace
			
		}
		
		cap destring age_ref, replace
		cap destring educ_ref, replace
		cap destring educa2, replace
		cap destring fam_size, replace
		cap destring fam_type, replace
		cap destring marital1, replace
		cap destring num_auto, replace
		cap destring popsize, replace
		cap destring race2, replace
		cap destring ref_race, replace
		cap destring region, replace
		cap destring cuid, replace
		cap destring no_earnr, replace
		cap destring qintrvmo, replace
		cap destring qintrvyr, replace
		

		save $temp/clean_cex_`year'`i'.dta, replace
		
		
	}
	
	}

	*Pulls in first quarter interview. I use the 1x interview series for all years so the questions match those in the rest of the year,
	*with the exception of 1996, 2005, and 2015 where I use the 1 series. The 1x series for these three years do not have any January interviews.
	
quietly forval year=1996(1)`yearmaxp1' {
   noi di `year'
	local pyear = `year'-1
	local yy2 = substr("`year'",3,2)
	local pyy2 = substr("`pyear'",3,2)

	
	
	if `year' != 2017 & `year' != 1999  & `year' != 1996 & `year' != 2005 & `year' != 2015 & `year' != 1994 &`year'!=1995		&`year'!= 1997 & `year'!=1998 & `year' != 2001 & `year' ~= 2019 & `year' ~= 2020 & `year' ~= 2021{
		use $temp/intrvw`yy2'/fmli`yy2'1x, clear
		}
		
	if `year' == 2017| `year' == 1998 | `year'==1997 | `year' == 1994 |`year' ==1995 | `year' ==2001 | `year' == 2019{
	 use $temp/intrvw`yy2'/intrvw`yy2'/fmli`yy2'1x.dta, clear
	}
	
	if `year' == 1999{
	 use $temp/fmli`yy2'1x.dta, clear 
	}
	
	if `year' == 1996{
	 use $temp/intrvw`pyy2'/intrvw`pyy2'/fmli`yy2'1.dta, clear
	}	
	
	if `year' == 2005 | `year' == 2015 | `year' == 2021{
	use $temp/intrvw`pyy2'/fmli`yy2'1, clear	
	}	
	
	if `year' ==2020{
	use $temp/intrvw`pyy2'/intrvw`pyy2'/fmli`yy2'1, clear	
	}		
	
	if `year'>2013{
	    di `year'
			keep $varlist_1318
			gen year = `year'
			gen qtrnum = 1
			cap tostring newid, replace
			
		}
		
		if `year' > 2003 & `year' < 2006{
			keep $varlist_0405
			gen year = `year'
			gen qtrnum = 1
			cap tostring newid, replace
		
		}
		
	if (`year' > 2000 & `year' < 2004) | (`year' < 2014 & `year'>2005){
		keep $varlist_0213
		cap destring newid, replace
		gen newid_ = newid
		tostring newid, replace
		gen cuid = substr(newid, 1, 6) if newid_ >= 1000000
		replace cuid = substr(newid, 1, 5) if newid_ < 1000000
		drop newid_
		gen year = `year'
		gen qtrnum = 1
		
	}
	
		if (`year' > 1994 & `year' < 2001) {
		keep $varlist_9501
		cap destring newid, replace
		gen newid_ = newid
		tostring newid, replace
		gen cuid = substr(newid, 1, 6) if newid_ >= 1000000
		replace cuid = substr(newid, 1, 5) if newid_ < 1000000
		drop newid_
		gen year = `year'
		gen qtrnum = 1
		
	}
		
	
		cap destring age_ref, replace
		cap destring educ_ref, replace
		cap destring educa2, replace
		cap destring fam_size, replace
		cap destring fam_type, replace
		cap destring marital1, replace
		cap destring num_auto, replace
		cap destring popsize, replace
		cap destring race2, replace
		cap destring ref_race, replace
		cap destring region, replace
		cap destring cuid, replace
		cap destring no_earnr, replace
		cap destring qintrvmo, replace
		cap destring qintrvyr, replace
		
		save $temp/clean_cex_`year'1.dta, replace

		
		
}




*Appends files
clear
set obs 1
gen blank = .

quietly forval year=`yearmin'(1)`yearmaxp1' {
    
	disp `year'
	forval i = 1/4{
		if `i' > 1 & `year' == `yearmaxp1'{
			
		}
	else{
	append using $temp/clean_cex_`year'`i'.dta
		    

	cap erase $temp/clean_cex_`year'`i'.dta
	}
	}
	
}
	
sort year qtrnum
	
	
/******************************************************************************
3. Cleans data and creates asset variables
******************************************************************************/
	
gen insample = 1
	
drop blank	

*Keeps only households that complete all four surveys
bys cuid: gen totint = _N
replace insample = 0 if totint < 4
drop totint

*Keeps only households age 25-64

replace insample =0 if age_ref < 25 | age_ref > 64

*Keeps both Urban and Rural households
replace insample = 0 if bls_urbn != "1"


*Keeps only complete income reporters & pre-tax income > 0


replace fincbtax = . if fincbtax <= 0
replace fincbtxm = . if fincbtxm <= 0

gen income = fincbtax 

replace income = fincbtxm if income == .
replace lumpsumx = 0 if lumpsumx == .
replace cshcntbx = 0 if cshcntbx == .
replace income = income + lumpsumx - cshcntbx // Adds in income from alimony, gifts, etc. and takes out income from paid alimony, etc.

*Note: I'm not doing the housing difference that Aguiar and Bils 2015 do since I'm looking at quarterly rather than annual data. Housing costs is at the quarterly level and income is at the annual level.

replace insample = 0 if income == . 




*Exclude households in the top- and bottom- 5 percent of distribution of pre-tax income
* and divides households into 5 income quintiles

sort cuid year qtrnum
by cuid: gen intrvw_num = _n

gen quarter = yq(year,qtrnum)
format quarter %tq

gen age = max(age_ref,age2)


reg income i.fam_size i.age  i.no_earnr [w=finlwt21] if insample
cap drop resid_
predict resid_, residual
gen residincome = resid_ + _b[_cons] if insample

preserve
keep if insample
gen i5 = residincome
gen i20 = residincome
gen i40 = residincome
gen i60 = residincome
gen i80 = residincome
gen i95 = residincome

collapse (p5) i5 (p20) i20 (p40) i40 (p60) i60 (p80) i80 (p95) i95 [w=finlwt21], by(quarter)

save $temp/income_levels.dta, replace
restore



merge m:1 quarter using $temp/income_levels.dta

replace insample = 0 if residincome > i95 | residincome < i5

gen income_group = 1 if residincome <= i20 & insample
replace income_group = 2 if residincome > i20 & residincome <= i40 & insample
replace income_group = 3 if residincome > i40 & residincome <=i60 & insample
replace income_group = 4 if residincome > i60 & residincome <= i80 & insample
replace income_group = 5 if residincome > i80 & residincome <= i95 & insample

replace income_group = . if insample == 0

drop i5 i95 i20 i40 i60 i80



*Liquid Wealth 2013-
replace creditx = 0 if creditx == . & intrvw_num == 4 & year > 2012
replace liquidx = 0 if liquidx == . & intrvw_num == 4 & year > 2012
gen temp_nliquid = liquidx -creditx
gen temp_liquid = liquidx

*Illiquid Wealth 2013-
replace irax = 0 if irax == . & intrvw_num ==4  & year > 2012
replace wholifx = 0 if wholifx == . & intrvw_num == 4  & year > 2012
replace othastx = 0 if othastx == . & intrvw_num == 4  & year > 2012
replace stockx = 0 if stockx == . & intrvw_num == 4  & year > 2012
replace othlonx = 0 if othlonx == . & intrvw_num == 4  & year > 2012
replace studntx = 0 if studntx == . & intrvw_num == 4  & year > 2012

gen temp_illiquid = irax + wholifx + othastx+stockx
gen temp_nilliquid = temp_illiquid - othlonx -studntx


*Liquid Wealth Pre-2013
replace ckbkactx = 0 if  ckbkactx == . & intrvw_num == 4 & year < 2013
replace savacctx = 0 if  savacctx == . & intrvw_num == 4 & year < 2013

replace temp_liquid = ckbkactx + savacctx

*Illiquid wealth Pre-2013
replace secestx = 0 if  secestx == . & intrvw_num == 4 & year < 2013
replace usbndx = 0 if usbndx  == . & intrvw_num == 4 & year < 2013
replace temp_illiquid = usbndx + secestx

egen liquid = max(temp_liquid),by(cuid)
egen nliquid = max(temp_nliquid),by(cuid)
egen illiquid = max(temp_illiquid),by(cuid)
egen nilliquid = max(temp_nilliquid),by(cuid)


drop temp*

gen assets = liquid + illiquid
gen nassets = nliquid + nilliquid


*Asset quartiles:

preserve
gen assets_p95 = assets
gen assets_p50 = assets
gen assets_p75 = assets
gen liquid_p95 = liquid
gen liquid_p50 = liquid
gen liquid_p75 = liquid
gen illiquid_p95 = illiquid
gen illiquid_p50 = illiquid
gen illiquid_p75 = illiquid
collapse (p95) assets_p95 liquid_p95 illiquid_p95 (median) assets_p50 liquid_p50 illiquid_p50 (p75) assets_p75 liquid_p75 illiquid_p75 [w=finlwt21], by(quarter)

save $temp/dist_assets_fmli.dta, replace

restore


merge m:1 quarter  using $temp/dist_assets_fmli.dta, nogen

gen assetsq = assets < assets_p50
replace assetsq = 2 if assets >= assets_p50 & assets < assets_p75
replace assetsq =3 if assets >= assets_p75 & assets < assets_p95
replace assetsq = 4 if assets >= assets_p95


gen liquidq = liquid < liquid_p50
replace liquidq = 2 if liquid >= liquid_p50 & liquid < liquid_p75
replace liquidq =3 if liquid >= liquid_p75 & liquid < liquid_p95
replace liquidq = 4 if liquid >= liquid_p95

gen illiquidq = illiquid < illiquid_p50
replace illiquidq = 2 if illiquid >= illiquid_p50 & illiquid < illiquid_p75
replace illiquidq =3 if illiquid >= illiquid_p75 & illiquid < illiquid_p95
replace illiquidq =4 if illiquid >= illiquid_p95



gen asseth = assets > assets_p50
gen liquidh = liquid > liquid_p50

*Label Variables:

label var liquid "Liquid Assets"
label var nliquid "Liquid Assets minus Credit Card Balance"
label var illiquid "Illiquid Assets"
label var nilliquid "Net Illiquid Assets"
label var assets "Total Assets"
label var nassets "Net Assets"
label var newid "Unique Household+ Interview Identifier"
label var cuid "Unique Household Identifier"
label var finlwt21 "Survey Weight"
label var hhid "Identifier for household with more than one CU. Household with only one CU will be set to missing."
label var assetsq "Asset group of household"
label var liquidq "Liquid Asset group of household"
label var illiquidq "Illiquid asset group of household"

label var asseth "Asset group of household"
label var liquidh "Liquid asset group of household"

label define agroup 1 "Below 50 Percentile" 2 "50-75 Percentile" 3 "75-90 Percentile" 4 "Above 95 Percentile"
label values assetsq liquidq illiquidq agroup

label define income_g 1 "5-20 Percentile" 2 "20-40 percentile" 3 "40-60 percentile" 4 "60-80 Percentile" 5 "80-95 Percentile" 
lab val income_group income_g
 
*Expenditure

replace cashcocq = 0 if cashcocq == . //Cash contributions and donations
replace cashcopq = 0 if cashcopq == .
gen total_contribution = cashcocq + cashcopq 
label var total_contribution "Total Donations and other cash contributions"



replace miscpq = 0 if miscpq == . //Misc. outlays
replace misccq = 0 if misccq == .
gen misc_outlay = miscpq + misccq

replace lifinspq = 0 if lifinspq == . //Life insurance
replace lifinscq = 0 if lifinscq == .
gen life = lifinscq + lifinspq

replace retpenpq = 0 if retpenpq == . //Pension and social security
replace retpencq = 0 if retpencq == .
gen pension = retpencq + retpenpq


*Health care expenditure is sometimes negative
gen neghealthpq = min(0,healthpq)
gen neghealthcq = min(0,healthcq)
gen neghealth = neghealthpq + neghealthcq

gen total_spending = totexppq + totexpcq -total_contribution - neghealth - pension - life 
label var total_spending "Total Household Spending Current Interview"

replace insample = 0 if total_spending < 0 //this only drops one observation, the problem with negative total_spending was basically solved by taking away health rebates


*Rental expenditure

gen rent = rendwecq + rendwepq


replace qintrvyr = 1900+ qintrvyr if qintrvyr < 1000
*Create interview month 
gen intmonth = ym(qintrvyr,qintrvmo)
label var intmonth "Month of interview"
format intmonth %tm



label data "Clean FMLI Files: CEX_1_hhinfo.do  5.17.22"

cap drop _merge
destring newid, replace

save $CEX/clean_fmli.dta, replace




*******ID variables
*NEWID
*CUID (digits 1-7 of NEWID) 2002-
*FINLWT21	Calibration final weight for the full sample
 *HHID	Identifier for household with more than one CU. Household with only one CU will be set to missing. 1990-




******Asset variables:
* LIQUDYRX	What was the total value of all checking, savings, money market accounts, and certificated of deposit or CDs one year ago today? 2013-
* LIQUIDX	As of today, what is the total value of all checking, savings, money market accounts, and certificated of deposit or CDs you have? 2013-

* CREDITX1	Total amount owed to credit sources 1994-2013 (file FN2)
* CREDITX5	Total amount owed as of last bill 1994-2013 (file FN2)
* CKBKACTX	Total balance or market value (including interest earned) CU had in checking accounts, brokerage accounts, and other similar accounts as of the last day of the previous month  1984-2013
*COMPCKGX	The difference in the amount held in checking accounts as of the last day of last month as compared with a year ago last month. 1984-2013
*COMPOWDX	The difference in the amount owed to CU by persons outside CU last month compared with the amount owed a year ago last month 1984-2013
*COMPSAVX	The difference in the amount held in savings accounts on the last day of last month compared with a year ago last month 1984-2013
*COMPSECX	The difference in the estimated market value of all stocks, bonds, mutual funds, and other such securities held by CU last month compared with the value of all securities held a year ago last month 1984-2013
*CREDITB	Could you tell me which range that best reflects the total amount owed on all major credit cards including store cards and gas cards? 2013-
*CREDITX	What is the total amount owed on all cards? 2013-
*CREDTYRX	What was the total amount owed on all cards one year ago today? 2013-
*IRAX	As of today, what is the total value of all retirement accounts, such as 401(k)s, IRAs, and Thrift Savings Plans that you own? 2013-
*IRAYRX	What was the total value of all retirement accounts one year ago today? 2013-
*NUM_AUTO	Total number of owned cars 1984-
*NUM_TVAN	Total number of owned trucks and vans 1997-
*OTHASTX	As of today, what is the total value of these other financial assets? 2013-
*OTHFINX	What was the total amount paid in finance, late charges, and interest for all other loans in the last month? 2013-
*OTHLNYRX	What was the total amount owed on all other loans one year ago today? 2013-
*OTHLONX	What is the total amount owed on all other loans? 2013-
*OTHSTYRX	What was the value of these other financial assets one year ago today? 2013-
*OWNDWECQ	Owned dwellings this quarter 1990-
*OTHVEHCQ	Other vehicles this quarter 1990-
*SAVACCTX	Total balance or market value (including interest earned) CU had in savings accounts in banks, savings and loans, credit unions, etc., as of the last day of previous month 1984-2013
*SECESTX	Estimated market value of all stocks, bonds, mutual funds, and other such securities held by CU on the last day of the previous month 1984-2013
*STDNTYRX	What was the total amount owed on all student loans one year ago today? 2013-
*STOCKX	As of today, what is the total value of all directly-held stocks, bonds, and mutual funds? 2013-
*STOCKYRX	What was the total value of all directly-held stocks, bonds, and mutual funds one year ago today? 2013-
*STUDNTX	What is the total amount owed on all student loans? 2013-
*USBNDX	Total balance or market value (including interest earned) CU had in U.S. Savings Bonds as of the last day of the previous month 1984-2013
*VEHQ	Total number of owned vehicles
*WHLFYRX	What was the total surrender value of these policies one year ago today? 2013-
*WHOLIFX	As of today, what is the total surrender value of these policies? 2013-




*******Income variables

*DIVX	Amount of regular income received from dividends, royalties, estates, or trusts 1984-2012
*EARNINCX	Total amount of family earnings income before taxes 1984-2004
*EITC	During the past 12 months, did you claim an Earned Income Tax Credit on your federal income tax return? 2013-2017
*FINCATAX	Total amount of family income after taxes in the last 12 months (Collected data) 1984-2004, 2006-2014
*FINCATXM	Total amount of family income after taxes in the last 12 months (Imputed or collected data) 2004-2014
*FINATXEM	Total amount of family income after estimated taxes in the last 12 months (Imputed or collected data) 2013-
*FINCBTAX	Total amount of family income before taxes in the last 12 months (Collected data) 1984- but with a gap in 2005
*FINCBTXM	Total amount of family income before taxes (Imputed or collected data) 2004-
*FININCX	Amount of regular income earned from dividends, royalties, estates, or trusts 1984-2013 but with gap in 2005
*FININCXM	Amount of regular income received from dividends, mean of imputation iterations. 2004-2013
*INC_RANK	Weighted cumulative percent ranking based on total current income before taxes 1984- with gap in 2005
*INC_RNKM	Weighted cumulative percent ranking based on total current income, based on mean of imputation iterations 2004-
*INTRDVX	Amount of income received from interest and dividends 2013-
*INTEARNM	Amount received as interest on savings accounts or bonds, mean of imputation iterations. 2004-2013
*NO_EARNX	Total amount of family income other than earnings before taxes 1984-2004
*POV_CY	CU below/not below the current year's poverty threshold? 1990-2014 gap in 2005
*POV_CYM	Is CU income below current year’s poverty threshold? (Income is defined as FINCBTXM-FOODSMPM.) 2004-2014

 


********Cumulative Expenditure variables (Detailed expenditure done in another do file)

*ERANK	Weighted cumulative percent expenditure ranking of CU to total population. Ranking based on total expenditures.  Includes vehicle payments, less UCC’s based on variables collected only in the fifth interview.  Rank of incomplete reporters of income are set to zero 1984-1995

*ERANKMTH	Dollar amount used for expenditure ranking (ERANKH and ERANKUH) based on expenditure outlays made during the reference (interview) period. Includes all mortgage and vehicle principal payments; excludes outlays for items collected only in the fifth interview 1994-2004, 2006-2011

*ERNKMTHM	Dollar amount used for expenditure ranking (ERANKHM) based on expenditure outlays made during the reference (interview) period. Includes all mortgage and vehicle principal payments; excludes outlays for items collected only in the fifth interview. 2004-2011

*ETOTACX4	Adjusted total outlays last quarter, sum of outlays from all major expenditure categories. 2000-

*ETOTALC	Total outlays this quarter, sum of outlays from all major expenditure categories. 2000-

*ETOTALP	Total outlays last quarter, sum of outlays from all major expenditure categories. 2000-

*TOTEX4CQ	Adjusted total expenditures this quarter collected in Interview Survey 1995-

*TOTEX4PQ	Adjusted total expenditures last quarter 1995-

*TOTEXPCQ	Total expenditures this quarter 1990-

*TOTEXPPQ	Total expenditures last quarter 1990-




*Demographic variables 
* age_ref: Age
* age2: Age of spouse
* educ_ref: education of reference person
*EDUCA2	What is the highest level of school the spouse has completed or the highest degree the member has received?
*FAM_SIZE	Number of Members in CU 1984-
*fam_type   code for type of family 1984-
*HIGH_EDU	Highest level of education within the CU. 2011-
*HISP_REF	Hispanic origin of reference person 2009-
*HORREF1	Hispanic Origin of the Reference Person 2003-
*HORREF2	Hispanic Origin of the spouse 2003-
*MARITAL1	Marital status of reference person
*PERSLT18	# of CU Members less than 18 AGE < 18
*PERSOT64	Number of persons over 64 SUM OF MEMBERS WHERE AGE > 64 BY CU
*POPSIZE	Population size of the PSU
*RACE2	Race of spouse
*REF_RACE	Race of reference person
*REGION	Region
*SEX_REF	Sex of reference person










