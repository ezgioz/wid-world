clear
clear matrix
clear mata
set maxvar 32000
use "$work_data/calculate-income-categories-output.dta", clear

// Keep only relevant data (we will update the full database afterwards)
keep if inlist(substr(widcode, 1, 1), "a", "s")

// Extend the currency to s- variables
rename currency currency2
egen currency = mode(currency2), by(iso year)
drop currency2

// Reshape to wide format
reshape wide value, i(iso year p) j(widcode) string

// Rename variables
foreach v of varlist value* {
	local varname = substr("`v'", 6, .)
	rename `v' `varname'
}

// Replace "." by "_" in p for compatibility with reshape
replace p = subinstr(p, ".", "_", 2)
// Add "__" in front of p to separate it clearly from variable name after reshape
replace p = "__" + p

// Make a list of income/wealth concepts
foreach v of varlist a* s* {
	local concept = substr("`v'", 2, strlen("`v'"))
	local conceptslist: list conceptslist | concept
}

// Reshape to put percentiles in the variables
reshape wide a* s*, i(iso year) j(p) string

// Loop over income/wealth concepts, and over percentiles to calculate o- variables
foreach c of local conceptslist {
	foreach p in p99_99 p99_95 p99_9 p99_75 p99_5 p99 p95 p90 {
		generate o`c'__`p' = .
	
		// Population size
		local perc = substr("`p'", 2, strlen("`p'"))
		local popsize = 1 - real(subinstr("`perc'", "_", ".", 1))/100
	
		// Case 1: there is an average variable for pXp100
		capture confirm variable a`c'__`p'p100
		if (_rc == 0) {
			replace o`c'__`p' = a`c'__`p'p100
		}
		
		// Case 2: there is a top share for pX and an average for pall
		capture confirm variable s`c'__`p' a`c'__pall
		if (_rc == 0) {
			replace o`c'__`p' = a`c'__pall*s`c'__`p'/`popsize' if (o`c'__`p' >= .)
		}
		
		// Case 3: there is a top share for pXp100 and an average for pall
		capture confirm variable s`c'__`p'p100 a`c'__pall
		if (_rc == 0) {
			replace o`c'__`p' = a`c'__pall*s`c'__`p'p100/`popsize' if (o`c'__`p' >= .) 
		}
		
		// Case 4: no direct information on average, but we can divide the
		// percentile in two fractiles
		foreach q in p99_99 p99_95 p99_9 p99_75 p99_5 p99 p95 p90 {
			local pnum = real(subinstr(substr("`p'", 2, strlen("`p'")), "_", ".", 1))
			local qnum = real(subinstr(substr("`q'", 2, strlen("`q'")), "_", ".", 1))
			if (`qnum' > `pnum') {
				// Population sizes in below and above q
				local popsize_above = 1 - `qnum'/100
				local popsize_below = (`qnum' - `pnum')/100
			
				// Temporary variables to store both components of the average
				tempvar below above
				
				// First, for the "above q" component: we use an o- variable,
				// which must have been calculated before if possible
				generate `above' = o`c'__`q'*`popsize_above'
				
				// Second, for the "below q" component: proceed case by case
				generate `below' = .
				// Case 4.1: there is an average for p`p'p`q'
				capture confirm variable a`c'__`p'`q'
				if (_rc == 0) {
					replace `below' = a`c'__`p'`q'*`popsize_below'
				}
				// Case 4.2: there is a share for p`p'p`q' and an average for pall
				capture confirm variable s`c'__`p'`q' a`c'__pall
				if (_rc == 0) {
					replace `below' = a`c'__pall*s`c'__`p'`q'*`popsize_below'
				}
				
				replace o`c'__`p' = (`below' + `above')/`popsize' ///
					if (`below' < .) & (`above' < .) & (o`c'__`p' >= .)
				drop `below' `above'
			}
		}
	}
}

// Drop o- variables with only missing information, and store the list of
// relatied income/wealth concepts otherwise
keep iso year currency o*
foreach v of varlist o* {
	quietly count if `v' < .
	if (r(N) == 0) {
		drop `v'
	}
	else {
		if regexm("`v'", "^(.+)__.+$") {
			local ov = regexs(1)
		}
		local ovars: list ovars | ov 
	}
}

// Reshape back to long format
reshape long `ovars', i(iso year) j(p) string

// Re-transform p2 to initial format
replace p = substr(p, 3, .)
replace p = subinstr(p, "_", ".", 1)

// Reshape back to initial format
reshape long o, i(iso year p) j(widcode) string
replace widcode = "o" + widcode
rename o value
drop if value >= .

append using "$work_data/calculate-income-categories-output.dta"

sort iso widcode p year

label data "Generated by calculate-average-over.do"
save "$work_data/calculate-average-over-output.dta", replace
