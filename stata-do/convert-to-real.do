use "$work_data/add-exchange-rates-output.dta", clear

merge n:1 iso year using "$work_data/price-index.dta", ///
	nogenerate keepusing(index) keep(master match)

*bys iso year : replace index = .00134171 if year == 1900 & iso == "ES" & index == .

// Attribute US deflator to US States
preserve
	keep if iso == "US"
	keep year index
	duplicates drop
	ren index us_index
	tempfile temp
	save `temp'
restore
merge m:1 year using `temp', nogen
replace index=us_index if substr(iso,1,3) == "US-"
drop us_index

// Check that there is always a price index for the nominal data
drop if mi(index) & iso == "IN" & year<1900 & substr(widcode,1,1) == "m"

merge n:1 iso using "$work_data/import-region-codes-output.dta", keepusing(iso) keep(master match)
generate is_region = (_merge == 3)
drop _merge

replace value = value/index if inlist(substr(widcode, 1, 1), "a", "m", "t", "o") ///
	& (substr(widcode, 4, 3) != "toq") ///
	& !is_region

assert !missing(index) if !inlist(iso, "CZ", "RU", "AU", "NZ", "CA", "ES", "ID") ///
	& inlist(substr(widcode, 1, 1), "a", "m", "t", "o") ///
	& (substr(widcode, 4, 3) != "toq") ///
	& strpos(widcode,"ptinc") == 0 ///
	& strpos(widcode,"diinc") == 0 ///
	& !is_region


tab iso if missing(index) & !inlist(iso, "CZ", "RU", "AU", "NZ", "CA", "ES") ///
	& inlist(substr(widcode, 1, 1), "a", "m", "t", "o") ///
	& (substr(widcode, 4, 3) != "toq") ///
	& strpos(widcode,"ptinc") == 0 ///
	& strpos(widcode,"diinc") == 0 ///
	& !is_region


// Convert monetary series to real $pastyear LCU

// We do not convert World Regions because they do not have a price index.
// They will be taken care of in calibrate-dina.do

drop index is_region

compress
label data "Generated by convert-to-real.do"
save "$work_data/convert-to-real-output.dta", replace
