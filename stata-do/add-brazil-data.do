import excel "$wid_dir/Country-Updates/Brazil/Brazil inequality series.xlsx", sheet("series") first case(l) clear
destring year, replace
levelsof year, local(years)
levelsof component, local(types)

foreach type in `types'{
qui{
foreach year in `years'{
		
		// Define widcodes and open corresponding sheets
		if "`type'"=="Fiscal income"{
			local inc fiinc
			import excel "$wid_dir/Country-Updates/Brazil/Brazil inequality series.xlsx", ///
				sheet("Fiscal income, Brazil, `year'") first clear
		}
		if "`type'"=="National income"{
			local inc ptinc
			import excel "$wid_dir/Country-Updates/Brazil/Brazil inequality series.xlsx", ///
				sheet("National income, Brazil, `year'") first clear
		}
	
		// Clean and extend
		destring year, replace
		replace year=year[_n-1] if _n>1
		replace country=country[_n-1] if _n>1
		replace average=average[_n-1] if _n>1
		replace p=p*100
		drop component

		// Bracket averages, shares, thresholds (pXpX+1)
		preserve
			keep country year p bracketavg bracketsh thr
			gen p2=p[_n+1] if _n<_N
			replace p2=100 if _n==_N
			gen x="p"
			egen perc=concat(x p x p2)
			keep year country perc bracketavg bracketsh thr

			rename bracketavg valuea`inc'992j
			rename bracketsh values`inc'992j
			rename thr valuet`inc'992j
			reshape long value, i(country year perc) j(widcode) string
			order country year perc widcode value
			tempfile brack`year'
			save "`brack`year''"
		restore

		// Top averages, shares, thresholds, beta (pXp100)
		preserve
			keep country year p topavg topsh thr b
			gen perc = "p" + string(p) + "p" + "100"
			drop p
			rename topavg valuea`inc'992j
			rename topsh values`inc'992j
			rename thr valuet`inc'992j
			rename b valueb`inc'992j
			reshape long value, i(country year perc) j(widcode) string
			order country year perc widcode value
			drop if mi(value)
			drop if substr(widcode, 1 , 1)=="b" & perc=="p0p100"
			tempfile top`year'
			save "`top`year''"
		restore

		// Key percentile groups
		preserve
			keep year country p average topsh
			replace p=p*1000

			gen aa=1-topsh if p==50000 //  bottom 50
			egen p0p50share=mean(aa)
			drop aa
			gen long p0p50Y=p0p50share*average/(0.5)

			gen aa=1-topsh if p==90000 // middle 40
			egen p50p90share=mean(aa)
			replace p50p90share=p50p90share-p0p50share
			drop aa
			gen long p50p90Y=p50p90share*average/(0.4)

			gen aa=topsh if p==90000 // top 10
			egen top10share=mean(aa)
			drop aa
			gen long top10Y=top10share*average/(0.1)

			gen aa=1-topsh if p==99000 // next 9
			egen p90p99share=mean(aa)
			replace p90p99share=p90p99share-(1-top10share)
			drop aa
			gen long p90p99Y=p90p99share*average/(0.09)

			gen aa=topsh if p==99000 // top 1
			egen top1share=mean(aa)
			drop aa
			gen long top1Y=top1share*average/(0.01)

			gen aa=topsh if p==99900 // top 0.1
			egen top01share=mean(aa)
			drop aa
			gen long top01Y=top01share*average/(0.001)

			gen aa=topsh if p==99990 // top 0.01
			egen top001share=mean(aa)
			drop aa
			gen long top001Y=top001share*average/(0.0001)

			keep p0p50* p50p90* p90p99* top1Y top1share top01* top001* year country
			keep if _n==1
			reshape long p0p50 p50p90 p90p99 top1 top01 top001, i(country year) j(Y) string
			foreach var in p0p50* p50p90* p90p99* top1* top01* top001*{
				rename `var' x`var'
			}
			reshape long  x, i(Y year) j(new) string
			replace Y="a`inc'992j" if Y=="Y"
			replace Y="s`inc'992j" if Y=="share"
			rename Y widcode
			rename new perc
			rename x value
			replace perc="p99p100" if perc=="top1"
			replace perc="p99.9p100" if perc=="top01"
			replace perc="p99.99p100" if perc=="top001"

			tempfile key`year'
			save "`key`year''"
		restore

		// Deciles
		preserve
			replace p=p*1000
			foreach p in 0 10000 20000 30000 40000 50000 60000 70000 80000{
				local p2=`p'+9000
				egen sh`p'=sum(bracketsh) if inrange(p,`p',`p2')
				gen avg`p'=(sh`p'*average)/0.1
				egen x=mean(sh`p')
				drop sh`p'
				rename x sh`p'
				egen x=mean(avg`p')
				drop avg`p'
				rename x avg`p'
			}
			keep country year sh* avg*
			keep if _n==1
			reshape long sh avg, i(country year) j(perc)
			rename avg valuea`inc'992j
			rename sh values`inc'992j
			reshape long value, i(country year perc) j(widcode) string
			replace perc=perc/1000
			gen perc2=perc+10
			tostring perc perc2, replace
			replace perc = "p" + perc + "p" + perc2
			drop perc2

			sort widcode perc
			bys widcode: assert value<value[_n+1] if _n<_N

			tempfile dec`year'
			save "`dec`year''"
		restore


		// Append all files
		use "`brack`year''", clear
		append using "`top`year''"
		append using "`key`year''"
		append using "`dec`year''"

		// Sanity checks
		qui tab widcode
		assert r(r)==4
		qui tab perc
		assert r(r)==265

		// Save
		tempfile `inc'`year'
		save "``inc'`year''"
}
}
}

// Append all years
local iter=1
foreach inc in fiinc ptinc{
foreach year in `years'{
	if `iter'==1{
		use "``inc'`year''", clear
	}
	else{
		append using "``inc'`year''"
	}
local iter=`iter'+1
}
}

rename country iso
rename perc p
duplicates drop iso year p widcode, force

// Currency, renaming, preparing variables to drop from old data
generate currency = "BRL" if inlist(substr(widcode, 1, 1), "a", "t", "m", "i")
replace iso="BR"
replace p="pall" if p=="p0p100"

tempfile brazil
save "`brazil'"

// Create metadata
generate sixlet = substr(widcode, 1, 6)
keep iso sixlet
duplicates drop
generate source = `"[URL][URL_LINK]http://wid.world/document/extreme-persistent-inequality-new-evidence-brazil-combining-national-accounts-surveys-fiscal-data-2001-2015-wid-world-working-paper-201712/[/URL_LINK]"' ///
	+ `"[URL_TEXT]Marc Morgan (2017), Extreme and Persistent Inequality: New Evidence for Brazil Combining National Accounts, Surveys and Fiscal Data, 2001-2015"' ///
	+ `"[/URL_TEXT][/URL]; "'
generate method = ""
tempfile meta
save "`meta'"

// Add data to WID
use "$work_data/add-macro-updates-output.dta", clear
gen oldobs=1
append using "`brazil'"
duplicates tag iso year p widcode, gen(dup)
qui count if dup==1 & iso!="BR"
assert r(N)==0
drop if oldobs==1 & dup==1
drop oldobs dup

label data "Generated by add-brazil-data.do"
save "$work_data/add-brazil-data-output.dta", replace

// Add metadata
use "$work_data/add-macro-updates-metadata.dta", clear
merge 1:1 iso sixlet using "`meta'", nogenerate update replace

label data "Generated by add-brazil-data.do"
save "$work_data/add-brazil-data-metadata.dta", replace

