/**********************************************************************;
* Project           : Heterogeneous Inflation
*
* Program name      : CEX_0_BLSdownload.do
*
* Author            : Jacob Orchard (Thanks to Johannes Wieland for similar code )
*
* Date created      : 04/15/2020
*
* Purpose           : Download raw CEX data from BLS website for 1984 onwards and
                        unzip.
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* 
*
**********************************************************************/



local yearmin = 1984
local yearmax = 2020


/*******************************************************************************
1. Download CEX files from BLS.
*******************************************************************************/

forvalues year=`yearmin'(1)`yearmax' {
	
	/* last two digits of year */
	local yy2 = substr("`year'",3,2)
	
	disp "`yy2'"
	
	/* download file from the BLS and store in RAW data folder */
	copy "https://www.bls.gov/cex/pumd/data/stata/intrvw`yy2'.zip" "$temp/intrvw`yy2'.zip", replace

}

/*******************************************************************************
2. Unzip CEX files
*******************************************************************************/

cd $temp

forval year = `yearmin'(1)`yearmax'{

/* last two digits of year */
	local yy2 = substr("`year'",3,2)
	
	disp "`yy2'"
	
	if `year' != 1999{
		unzipfile intrvw`yy2'.zip, replace
		erase intrvw`yy2'.zip
    }
	
}

*99 is a zip within a zip
_renamefile intrvw99.zip ointrvw99.zip
unzipfile ointrvw99.zip, replace
erase ointrvw99.zip

unzipfile intrvw99.zip, replace

erase intrvw99.zip
erase expn99.zip

cd ../../






