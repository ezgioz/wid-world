// -------------------------------------------------------------------------- //
// Prepare carbon macro & distributional data 
// this is an independant do-file, it should be run along other do-files but 
// the carbon shall be separated from the rest and imported alone
// -------------------------------------------------------------------------- //

// Import population data from WID
use "$work_data/calculate-gini-coef-output.dta", clear

keep if inlist(widcode, "npopul999i")
reshape wide value, i(iso year p) j(widcode) string
keep iso year p valuenpopul999i
tempfile pop
save "`pop'"

use "$wid_dir/Country-Updates/Carbon/macro/April_2021/carbon.dta", clear
merge n:1 iso year using "`pop'", nogenerate keep(match)

replace value = value*1e6

generate value999i = value/valuenpopul999i

drop value valuenpopul999i

reshape long value, i(iso year p widcode source method data_quality ///
					  data_points extrapolation) j(pop) string
replace widcode = "k" + substr(widcode, 2, 5) + pop

drop pop
drop if missing(value)

duplicates tag iso year widcode p, gen(dup)
assert dup == 0
drop dup

tempfile percapita
save `percapita'

use "$wid_dir/Country-Updates/Carbon/macro/April_2021/carbon.dta", clear
append using "`percapita'"
append using "$wid_dir/Country-Updates/Carbon/distribution/July_2021/carbon-distribution-2021.dta"
keep iso year p widcode value

duplicates tag iso year widcode p, gen(dup)
assert dup == 0
drop dup

duplicates drop iso year p widcode, force

compress
label data "Generated by add-carbon-series.do"
save "$work_data/add-carbon-series-output.dta", replace

