import delimited "$wb_data/ppp/API_PA.NUS.PPP_DS2_en_csv_v2_$pastyear.csv", ///
	clear encoding("utf8") rowrange(3) varnames(4) 

// Rename year variables
dropmiss, force
foreach v of varlist v*{
	local year: variable label `v'
	rename `v' value`year'
}

// Identify countries
replace countryname = "Macedonia, FYR" if countryname == "North Macedonia"
replace countryname = "Swaziland"      if countryname == "Eswatini"
countrycode countryname, generate(iso) from("wb")

// Add currency from the metadata
merge n:1 countryname using "$work_data/wb-metadata.dta", ///
	keep(master match) nogenerate // Regions are dropped

// Identify currencies
replace currency = "turkmenistan manat" if currency == "New Turkmen manat"
currencycode currency, generate(currency_iso) iso2c(iso) from("wb")
drop currency
rename currency_iso currency

keep iso currency value*

reshape long value, i(iso) j(year)

// Add back Syria data point that was removed in 2021
replace value = 21.32 if year == 2011 & iso == "SY"

drop if value >= .

rename value ppp_wb

*keep if year == 2011
gegen max_year = max(year), by(iso)
keep if year == min(2017, max_year)
drop max_year

label data "Generated by import-ppp-wb.do"
save "$work_data/ppp-wb.dta", replace
