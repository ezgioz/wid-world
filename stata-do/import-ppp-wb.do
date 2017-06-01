import delimited "$wb_data/ppp/API_PA.NUS.PPP_DS2_en_csv_v2.csv", ///
	clear encoding("utf8") rowrange(3) varnames(4)

// Rename year variables
dropmiss, force
foreach v of varlist v*{
	local year: variable label `v'
	rename `v' value`year'
}

// Identify countries
countrycode countryname, generate(iso) from("wb")

// Add currency from the metadata
merge n:1 countryname using "$work_data/wb-metadata.dta", ///
	keep(master match) assert(match) nogenerate

// Identify currencies
currencycode currency, generate(currency_iso) iso2c(iso) from("wb")
drop currency
rename currency_iso currency

keep iso currency value*

reshape long value, i(iso) j(year)
drop if value >= .

rename value ppp_wb

keep if year == 2011

label data "Generated by import-ppp-wb.do"
save "$work_data/ppp-wb.dta", replace
