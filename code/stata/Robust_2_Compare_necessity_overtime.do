/**********************************************************************;
* Project           : Competing for Necessities
*
* Program name      : Robust_2_Compare_necessity_overtime.do
*
* Author            : Jacob Orchard 
*
* Date created      : 6/28/2021
*
* Purpose           : Creates expenditure weights based on MTBI CEX files. Isolates by decade
*s
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* 
**********************************************************************/

clear all


/******************************************************************************
1. Pull in Necessity rank data
******************************************************************************/

local decadelist `"1990" "2000" "2010" ""'

foreach decade in "`decadelist'"{
import excel using output/necessity_list`decade', clear
rename (A B C) (CPICategory ratio_total`decade' aggshare`decade')
tempfile rank`decade'
save `rank`decade''
}

use `rank'
merge 1:1 CPICategory using `rank1990', nogen
merge 1:1 CPICategory using `rank2000', nogen
merge 1:1 CPICategory using `rank2010', nogen


*Renames some categories to help with display in vizualization

replace CPICategory = "Club Memberships" if CPICategory == "Club memberships for shopping clubs, fraternal, or other organizations"
replace CPICategory = "Hotels and Motels" if CPICategory == "Other Lodging away from home including hotels and motels"
replace CPICategory = "Nursing homes" if CPICategory == "Nursing homes and adult day services"
replace CPICategory = "Other Tobacco" if CPICategory == "Tobacco products other than cigarettes"
replace CPICategory = "Water/Sewage Maintenance" if CPICategory == "Water and sewerage maintenance "

/******************************************************************************
2. Vizualization of how the top 10 Necessity goods change overtime
*******************************************************************************/
preserve
sort ratio_total 
gen rankpool = _n

sort ratio_total1990
gen rank1990 = _n

sort ratio_total2000
gen rank2000 = _n

sort ratio_total2010
gen rank2010 = _n

rename ratio_total expratio_pool
rename aggshare aggsharepool

reshape long ratio_total aggshare rank, i(CPICategory) j(decade)

egen CPIgroup = group(CPICategory)

labmask CPIgroup, values(CPICategory)
xtset CPIgroup decade

xtline rank if rankpool<11, overlay recast(connected) ytitle("") xtitle("Decade") xlabel(1990(10)2010)
graph export output/necessityrank_change_overtime.png, replace
restore

/******************************************************************************
3. Vizualization of how the top 10 Luxury goods change overtime
*******************************************************************************/

preserve

gsort -ratio_total 
gen rankpool = _n

gsort -ratio_total1990
gen rank1990 = _n

gsort -ratio_total2000
gen rank2000 = _n

gsort -ratio_total2010
gen rank2010 = _n

rename ratio_total expratio_pool
rename aggshare aggsharepool

reshape long ratio_total aggshare rank, i(CPICategory) j(decade)

egen CPIgroup = group(CPICategory)

labmask CPIgroup, values(CPICategory)
xtset CPIgroup decade

xtline rank if rankpool<11, overlay recast(connected) ytitle("") xtitle("Decade") xlabel(1990(10)2010)
graph export output/luxuryrank_change_overtime.png, replace

restore


/*****************************************************************************
4. How does a simple categorization of necessities change overtime?
*******************************************************************************/

gen necessity = ratio_total < 1
gen necessity1990 =ratio_total1990 <1
gen necessity2000 = ratio_total2000<1
gen necessity2010 = ratio_total2010 <1

tab necessity necessity2010
tab necessity necessity1990

reg ratio_total1990 ratio_total2010

reg necessity2010 necessity1990

probit necessity2010 necessity1990

margins ,dydx(necessity1990) atmeans


