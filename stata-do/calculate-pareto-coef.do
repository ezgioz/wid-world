use "$work_data/clean-up-output.dta", clear

// Keep thresholds and top averages only
keep if (substr(widcode, 1, 1) == "a" & regexm(p, "^p([0-9\.]+)p100$")) | ///
	(substr(widcode, 1, 1) == "t" & regexm(p, "^p([0-9\.]+)p100$"))

// Split widcode
generate onelet = substr(widcode, 1, 1)
generate vartype = substr(widcode, 2, .)

// Get percentile
generate long perc = round(1e3*real(regexs(1))) if (regexm(p, "^p([0-9\.]+)(p100)?$"))
drop p widcode

greshape wide value, i(iso year perc vartype) j(onelet) string

// Calculate Pareto coefficient
generate value = valuea/valuet
drop if missing(value)
drop valuea valuet

generate widcode = "b" + vartype
drop vartype

generate p = "p" + string(perc/1e3) + "p100"
drop perc

tempfile bp
save "`bp'"

// Add to the data
use "$work_data/clean-up-output.dta", clear

drop if substr(widcode, 1, 1) == "b"

append using "`bp'"

drop if year > $pastyear

label data "Generated by calculate-pareto-coef.do"
save "$work_data/calculate-pareto-coef-output.dta", replace
