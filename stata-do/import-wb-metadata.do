import excel "$wb_data/metadata/wb-metadata-2020.xlsx", ///
	sheet("Country - Metadata") clear firstrow case(lower)
	
rename currencyunit currency
rename tablename countryname

// Retrieve fiscal year
generate fiscalyearend = ustrregexs(2) ///
	if ustrregexm(specialnotes, "Fiscal year end(:|s on )(.*?);")
generate reportingperiod = ustrregexs(1) ///
	if ustrregexm(specialnotes, "reporting period for national accounts data: ([A-Z]{2})")

// Keep the fiscal year end only if data are reported according to it
replace fiscalyearend = "" if reportingperiod == "CY"
drop reportingperiod

keep countryname currency fiscalyearend

// Some discrepancies between the country names in the data and the metadata files
replace countryname = "Cote d'Ivoire" if (countryname == "Côte d'Ivoire")
replace countryname = "Curacao" if (countryname == "Curaçao")
replace countryname = "Korea, Dem. People’s Rep." if (countryname == "Korea, Dem. People's Rep.")
replace countryname = "Sao Tome and Principe" if (countryname == "São Tomé and Principe")
replace countryname = "Macedonia, FYR" if countryname == "North Macedonia"
replace countryname = "Swaziland" if countryname == "Eswatini"

replace currency = "swaziland lilangeni" if currency == "Swazi lilangeni"

label data "Generated by import-wb-metadata.do"
save "$work_data/wb-metadata.dta", replace
