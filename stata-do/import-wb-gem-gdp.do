import excel "$wb_data/global-economic-monitor/2019/GDP at market prices, current LCU, millions, seas. adj..xlsx", ///
	clear allstring
sxpose, clear

ds _var1, not
foreach v of varlist `r(varlist)' {
	local year = `v'[1]
	rename `v' value`year'
}
drop in 1
destring value*, replace force
dropmiss, force

egen countmiss = rowmiss(value*)
drop if countmiss == 33
drop countmiss

rename _var1 country

replace country = "Macedonia, FYR"       if country == "North Macedonia"
replace country = "Moldova".             if country == "Moldova, Rep."
replace country = "Egypt, Arab Rep."     if country == "Egypt Arab Rep."
replace country = "Hong Kong SAR, China" if  country == "Hong Kong China"
replace country = "Iran, Islamic Rep."   if  country == "Iran Islamic Rep."
replace country = "Korea, Rep."          if  country == "Korea Rep."
replace country = "Macedonia, FYR"       if  country == "Macedonia FYR"
replace country = "Slovakia"             if  country == "Slovak Republic"
replace country = "Taiwan, China"        if country == "Taiwan China"
drop if country == "Maldives"

countrycode country, generate(iso) from("wb gem")
drop country

/*
// Identify problems in the data
replace value2015 = . if (iso == "AR")
replace value2015 = . if (iso == "IR")
*/

// Iran has problematic value for 2018
replace value2018 = . if (iso == "IR")

// Consistency checks
local pastyear `"$pastyear"'
local prepastyear = ($pastyear - 1)
local preprepastyear = ($pastyear - 2)

br  if (value`prepastyear' < .)
assert abs(value`prepastyear' - value`preprepastyear')/value`prepastyear' < 0.5 if (value`prepastyear' < .)
*assert abs(value`pastyear' - value`prepastyear')/value`pastyear' < 0.5 if (value`pastyear' < .)

reshape long value, i(iso) j(year)
drop if value >= .
replace value = value*1e6
rename value gdp_lcu_gem

drop if year==$year

label data "Generated by import-wb-gem-gdp.do"
save "$work_data/wb-gem-gdp.dta", replace
