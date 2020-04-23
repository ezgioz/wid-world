// Label the variables ------------------------------------------------------ //

use "$work_data/calculate-gini-coef-output.dta", clear

keep widcode
duplicates drop

generate onetype = substr(widcode, 1, 1)
generate twolet = substr(widcode, 2, 2)
generate threelet = substr(widcode, 4, 3)

generate agecode = substr(widcode, 7, 3)
generate onepop = substr(widcode, 10, 1)

generate varunit = "no unit"
replace varunit = "constant 2015 local currency" if inlist(onetype, "a", "t", "m", "o")
replace varunit = "% of national income" if (onetype == "w")
replace varunit = "population" if inlist(onetype, "n", "h", "f")
replace varunit = "share of total (ratio)" if inlist(onetype, "c", "s")
replace varunit = "local currency per foreign currency" if (onetype == "x")

merge n:1 twolet threelet using "$work_data/var-names.dta", ///
	assert(match using) keep(match) keepusing(shortname) nogenerate
rename shortname varname

merge n:1 onepop using "$work_data/var-pops.dta", ///
	assert(match using) keep(match) keepusing(shortdes) nogenerate
rename shortdes varpop

merge n:1 onetype using "$work_data/var-types.dta", ///
	assert(match using) keep(match) keepusing(shortdes) nogenerate
rename shortdes vartype

merge n:1 agecode using "$work_data/var-ages.dta", ///
	assert(match using) keep(match) keepusing(shortname) nogenerate
rename shortname varage

generate varlabel = varname + " / " + varpop + " / " + vartype + " / " + varage + " / " + varunit
replace varlabel = varpop + " / " + varage if (vartype == "Population")

keep widcode varlabel

quietly levelsof widcode, local(widcode_list)
foreach c of local widcode_list {
	quietly levelsof varlabel if (widcode == "`c'"), local(varlabel)
	local `c' `varlabel'
}

// Reshape the dataset (long)------------------------------------------------------ //

use "$work_data/calculate-gini-coef-output.dta", clear

drop if strpos(iso, "XQ")

// Drop German Ginis (not correct)
drop if (iso == "DE") & substr(widcode, 1, 1) == "g"

// Change Kosovo code
replace iso="KV" if iso=="KS"

// Round up some variables
replace value = round(value, 0.1) if inlist(substr(widcode,1,1),"a","t")
replace value = round(value, 1) if inlist(substr(widcode,1,1),"m","n")
replace value = round(value, 0.0001) if inlist(substr(widcode,1,1),"s")

compress

save "$work_data/wid-long.dta", replace

/*
if substr("`c(pwd)'",1,10)=="C:\Users\A"{
	rsource, noloutput rpath("$r_dir") terminator(END_OF_R) roptions(`" --vanilla --args "$work_data" "')
	library(haven)
	library(reshape2)
	library(magrittr)

	path <- "C:/Users/Amory/Documents/GitHub/wid-world/work-data"

	setwd(path)
	data <- read_dta(paste0(path, "/wid-long.dta"))
	data %<>% dcast(iso + year + p ~ widcode, value.var = "value")
	write_dta(data, paste0(path, "/wid-wide.dta"))
}
*/
// A piece of R code
/*
rsource, noloutput rpath("$r_dir") terminator(END_OF_R) roptions(`" --vanilla --args "$work_data" "')

library(haven)
library(reshape2)
library(magrittr)

path <- commandArgs(trailingOnly = TRUE)

setwd(path)
data <- read_dta(paste0(path, "/wid-long.dta"))
data %<>% dcast(iso + year + p ~ widcode, value.var = "value")
write_dta(data, paste0(path, "/wid-wide.dta"))

END_OF_R
*/

// Reshape wide the dataset------------------------------------------------------//
greshape wide value, i(iso year p) j(widcode) string
renvars valueacainc992j - valuexlcyux999i, predrop(5)

save "$work_data/wid-wide.dta", replace

// Wide format
use "$work_data/wid-wide.dta", clear

label variable year "year"
label variable iso "ISO-2 country code"
label variable p "percentile; meaning varies with variable, see http://wid.world/percentiles/"
notes p: Percentile. Warning: percentile may have different meanings depending ///
on whether it is of the form pX or pXpY and depending on the type of variable ///
it is associated with (share variables, average variables or top average variables). ///
When p2 is of the form pX: Share variables (starting with « s ») return the ///
income or wealth share for all individuals over percentile threshold pX. Eg. ///
sptinc992i(p90) indicates the pre tax income share of top 10% adult individuals. ///
Average variables (starting with  « a ») return the average income or wealth of ///
a given variable between pX and the next consecutive percentile available for ///
the given income or wealth concept and country selected. Eg. aptinc992i(p99,US) ///
stores the average pre tax income of percentile group p99.0p99.1 in the US (the ///
lowest 10% earners within the top 1% adult pre tax income earners). ///
Threshold variables (starting with « t ») the income or wealth threshold ///
corresponding to percentile pX. ///
Top average variables (starting with « o ») return average income or wealth over pX. ///
When percentile notation is pXpY: ///
Share variables (starting with « s ») return the income or wealth share of ///
fractile group pXpY. ///
Average variables (starting with « a ») return, for a given pXpY, the average ///
income within fractile group pXpY. ///
Threshold variables (starting with « t ») return for a given percentile pXpY, ///
the income or wealth threshold corresponding to percentile pX. ///
Top average variables (starting with « o ») return average income or wealth over pY.

// Without labels
preserve

sort iso p year

label data "Generated by create-main-db.do"
save "$work_data/wid-final.dta", replace

restore

// With labels
if ($export_with_labels) {
	local nobs = _N + 1
	set obs `nobs'

	foreach v of varlist value* {
		local newvarname = substr("`v'", 6, .)
		rename `v' `newvarname'
		label variable `newvarname' `"``newvarname''"'
		notes `newvarname': ``newvarname''
		
		tostring `newvarname', force replace
		replace `newvarname' = "" if (`newvarname' == ".")
		replace `newvarname' = `"``newvarname''"' in `nobs'
	}

	sort iso p year

	replace iso = "ISO-2 country code" in 1
	replace p = "percentile; meaning varies with variable, see http://wid.world/percentiles/" in 1

	label data "Generated by create-main-db.do"
	save "$work_data/wid-final-with-label.dta", replace
}


// Erase temporary files
erase "$work_data/wid-long.dta"
erase "$work_data/wid-wide.dta"


