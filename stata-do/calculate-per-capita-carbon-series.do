// Impute per-capita carbon series

use "$work_data/World-and-regional-aggregates-output.dta", clear

// Data with adult population
keep if inlist(widcode, "npopul999i")
reshape wide value, i(iso year p) j(widcode) string
keep iso year p valuenpopul999i
tempfile pop
save "`pop'"


use "$work_data/World-and-regional-aggregates-output.dta", clear
keep if substr(widcode, 1, 1) == "e"

merge n:1 iso year using "`pop'", nogenerate keep(match)

replace value = value*1e6

generate value999i = value/valuenpopul999i

keep iso year widcode p currency value999i 

reshape long value, i(iso year p widcode) j(pop) string
replace widcode = "k" + substr(widcode, 2, 5) + pop

drop pop
drop if missing(value)

append using "$work_data/World-and-regional-aggregates-output.dta",

duplicates drop iso year p widcode, force

compress
label data "Generated by calculate-per-capita-carbon-series.do"
save "$work_data/calculate-per-capita-series-carbon-output.dta", replace
