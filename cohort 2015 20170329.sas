/* program to create cohort of AF patients (1 inpatient or 2 outpatient in the same year)
		- exclude valvular AF
		- exclude if rx = 0

Years: 2007-2015(Sept 30)
Age: 18-100

Varibles to include:
	- enrolid
	- AFdate
	- startdt: first enrolment date
	- enddt: last enrolment date
	- dobyr: year of birth
	- age_af: age at AF diagnosis
	- sex (1 - man, 2 - woman)
	- MSA
	- EGEOLOC: employer geographical location
	- warfarin: indicator for warfarin use
	- dabigatran: indicator for dabigatran use
	- rivaroxaban: indicator for rivaroxaban use
	- apixaban: indicator for apixaban use
	- edoxaban: indicator for edoxaban use
	- warfarin_dt: first prescription for warfarin (missing if no prescription)
	- dabigatran_dt: idem for dabigatran
	- rivaroxaban_dt: idem for rivaroxaban
	- apixaban_dt: idem for apixabam
	- edoxaban_dt : idem for edoxaban
	- xx_strength: strength of the the 1st prescription for each specific OAC

Restrict to:
	- those with rx=1
	- no valvular AF

*/

* 7-23-2014: noticed that 2012 wasn't included in the denominator file--added those data sets and need to re-run;
* 7-24-2014: started working on the OAC use indicators;
* 7-30-2014: added indicator variables for OAC use, and first date of use, but need to run in the entire cohort;
* 4-14-2015: labeled program, included all years;
* 6-18-2015: added 2013 and missing 2012 data;
* 6-19-2015: added code to delete unnecessary datasets;
* 3-21-2016: added 2014 data, changed name to cohort 2014, 
		changed the outpatient claim criteria to 7-365 days instead of 1-365 days,
		used age 18 and older instead of 21 and older;
* 10-14-2016: added dose of 1st prescription for each OAC as new variables and adapted libraries to Emory computer;
* 12-06-2016: changed program to select first enrollment period instead of creating discont variable;
* 03-29-2017: added 2015 data (through 9/30/15, changed name to cohort 2015
		added edoxaban;

libname msformat 'C:\Users\aalons3\Documents\NOACs in AF\MarketScan\formats';
*libname mscan 'C:\Users\aalons3\Documents\NOACs in AF\MarketScan\data';
libname mscan 'E:\';

options fmtsearch=(msformat);


data enrolment; 
	set mscan.ccaet073 mscan.ccaet083 mscan.ccaet093 mscan.ccaet102 mscan.ccaet111 mscan.ccaet121 mscan.ccaet122 mscan.ccaet131 mscan.ccaet141 mscan.ccaet151
		mscan.mdcrt073 mscan.mdcrt083 mscan.mdcrt093 mscan.mdcrt102 mscan.mdcrt111 mscan.mdcrt121 mscan.mdcrt122 mscan.mdcrt131 mscan.mdcrt141 mscan.mdcrt151;

	if rx="1"; * only includes enrolment months with available drug claims data;

	keep enrolid dtstart dtend sex dobyr msa egeoloc;
run;

proc sort data=enrolment; by enrolid dtstart; run;

data enrolment1;
	set enrolment;
	by enrolid;

	format startdt enddt mmddyy10.;
 
	if first.enrolid then do;
		startdt = dtstart; enddt = dtend; msarea=msa; geoloc=egeoloc; 
	end;

	if enrolid = lag(enrolid)
		and dtstart = lag(dtend)+1 then do;
		startdt = min(startdt, dtstart);
		enddt = max(enddt, dtend);
	end;

	if enrolid = lag(enrolid)
		and dtstart ~= lag(dtend)+1 then do;
		output;
		startdt = dtstart; enddt = dtend;
	end;

	else if last.enrolid then output;

	retain startdt enddt msarea geoloc ;

	keep enrolid startdt enddt sex dobyr msarea geoloc;
run;

data enrolment1b;
	set enrolment1;
	by enrolid;

	if first.enrolid then output; * select first enrollment period;
run;

data enrolment2; * code to drop enrollment periods starting on or after Oct 1, 2015 and to end follow-up by Sep 30, 2015;
	set enrolment1b;

	if startdt >= mdy(10,1,2015) then delete;
	if enddt >= mdy(10,1,2015) then enddt = mdy(9,30,2015);
run;


proc datasets library=work;
	delete enrolment enrolment1 enrolment1b;
run;

* defining date of AF diagnosis;

* inpatient;
data inclaims; 
	set mscan.ccaei073 mscan.ccaei083 mscan.ccaei093 mscan.ccaei102 mscan.ccaei111 mscan.ccaei121 mscan.ccaei122 mscan.ccaei131 mscan.ccaei141 mscan.ccaei151 
		mscan.mdcri073 mscan.mdcri083 mscan.mdcri093 mscan.mdcri102 mscan.mdcri111 mscan.mdcri121 mscan.mdcri122 mscan.mdcri131 mscan.mdcri141 mscan.mdcri151;
	where rx="1"; *only includes claims occurring in months with information on drug claims;
run;

data inpatient_af inpatient_valve;
	set inclaims;

	array dx_ $ dx1-dx15;

	do over dx_;
		if substr(dx_,1,4)="4273" then afib_in=1; 
		if substr(dx_,1,4) in ("3940" "4240") then valv_dz=1; *394.0 mitral stenosis, 424.0 mitral valve disorder;
	end;

	keep enrolid afib_in valv_dz disdate;

	if afib_in then output inpatient_af; *creates data set with all inpatient claims including AF/aflutter code;
	if valv_dz then output inpatient_valve; *creates data set with all inpatient claims including valvular dz;
run;

proc sort data=inpatient_af; by enrolid; run;
data inpatient_af1; *creates data set with first AF inpatient claim;
	set inpatient_af;
	by enrolid;

	if first.enrolid then output;
run;
	
proc sort data=inpatient_valve; by enrolid; run;
data inpatient_valve1; *creates data set with first valvular dz inpatient claim;
	set inpatient_valve;
	by enrolid;

	keep enrolid valv_dz;

	if first.enrolid then output;
run;

proc datasets library = work;
	delete inclaims inpatient_af inpatient_valve;
run;

* Outpatient AF;

data outclaims;
	set mscan.ccaeo073 mscan.ccaeo083 mscan.ccaeo093 mscan.ccaeo102 mscan.ccaeo111 mscan.ccaeo121 mscan.ccaeo122 mscan.ccaeo131 mscan.ccaeo141 mscan.ccaeo151 
		mscan.mdcro073 mscan.mdcro083 mscan.mdcro093 mscan.mdcro102 mscan.mdcro111 mscan.mdcro121 mscan.mdcro122 mscan.mdcro131 mscan.mdcro141 mscan.mdcro151;
	where rx="1"; *only includes claims occurring in months with information on drug claims;
run;

data outpatient_af; *creates data set with all the outpatient AF claims;
	set outclaims;

	array dx_ $ dx1-dx4;

	do over dx_;
		if substr(dx_,1,4)="4273" then afib_out=1;
	end;

	keep enrolid afib_out svcdate;

	if afib_out;
run;

proc sort data=outpatient_af; by enrolid svcdate; run;

data outpatient_af1; * creates data set with those with 2+ outpatient claims >=7 days and <=1 year apart;
	set outpatient_af;
	by enrolid;

	lag_visit=svcdate-lag(svcdate);
	if first.enrolid then lag_visit=.;

	if 6<lag_visit<366 then afib_out2=1;

	if afib_out2=1;
run;

proc datasets library = work;
	delete outpatient_af;
run;

data outpatient_af2; * creates data set with the first outpatient claim meeting the criteria of 2nd claim >1d, <1yr after other AF outpatient claim;
	set outpatient_af1;
	by enrolid;

	if first.enrolid then output;
	keep enrolid afib_out2 svcdate;
run;

proc datasets library = work;
	delete outpatient_af1;
run;

* Merge inpatient and outpatient IDs, inpatient valve dz, select earliest diagnosis, exclude valve dz;

proc sort data=inpatient_af1; by enrolid; run;
proc sort data=inpatient_valve1; by enrolid; run;
proc sort data=outpatient_af2; by enrolid; run;

data af_id;
	merge inpatient_af1 outpatient_af2 inpatient_valve1;
	by enrolid;

	afdate=min(svcdate,disdate); * AFDATE defined as the earliest of inpatient or outpatient diagnosis;
	format afdate mmddyy10.;

	keep enrolid afdate;

	if valv_dz not eq 1;
run;


proc datasets library = work;
	delete inpatient_af1 outpatient_af2 inpatient_valve1;
run;

* use of warfarin, dabigatran, rivaroxaban;
data meds;
	set mscan.ccaed073 mscan.ccaed083 mscan.ccaed093 mscan.ccaed102 mscan.ccaed111 mscan.ccaed121 mscan.ccaed122 mscan.ccaed131 mscan.ccaed141 mscan.ccaed151 
		mscan.mdcrd073 mscan.mdcrd083 mscan.mdcrd093 mscan.mdcrd102 mscan.mdcrd111 mscan.mdcrd121 mscan.mdcrd122 mscan.mdcrd131 mscan.mdcrd141 mscan.mdcrd151;

	format ndcnum $ndcprod.;

	keep enrolid svcdate ndcnum;
run;

data redbook;
	set mscan.redbook2015;

	rename ndcnum=ndcnum_;

	keep ndcnum therdtl strngth;
run;
/* warfarin:    therdtl = 2012040050
   dabigatran:  therdtl = 2012040016
   rivaroxaban: therdtl = 2012040043
   apixaban:	therdtl = 2012040012
   edoxaban: 	therdtl = 2012040023
*/

/*data one_;*/
/*	set one;*/
/*	rename enrolid=id; * rename ENROLID variable to have different name from the MEDS dataset;*/
/*	keep enrolid startdt indexdt_;*/
/*run;*/
/**/
/*proc sql noprint;*/
/*create table outclaims2 as*/
/*select enrolid, indexdt_, svcdate, dx1, dx2, proc1*/
/*from one_, outclaims*/
/*where id=enrolid and startdt<=svcdate<=indexdt_*/
/*;*/
/*quit;*/

proc sql noprint;
create table meds2 as
select enrolid, svcdate, therdtl, ndcnum, strngth
from meds, redbook
where ndcnum=ndcnum_ and therdtl in (2012040050 2012040016 2012040043 2012040012 2012040023)
;
quit;

proc sort data=meds2; by enrolid svcdate; run;

data meds3;
	set meds2;
	by enrolid;

	format warfarin_strength dabigatran_strength rivaroxaban_strength apixaban_strength edoxaban_strength $8.;
	format warfarin_dt dabigatran_dt rivaroxaban_dt apixaban_dt edoxaban_dt mmddyy10.;

	if first.enrolid then do;
		warfarin=0; 	warfarin_dt=.;		warfarin_strength = "";
		dabigatran=0;	dabigatran_dt=.;	dabigatran_strength = "";
		rivaroxaban=0;	rivaroxaban_dt=.;	rivaroxaban_strength = "";
		apixaban=0;		apixaban_dt=.;		apixaban_strength = "";
		edoxaban = 0;	edoxaban_dt = .;	edoxaban_strength = "";
	end;

	if therdtl=2012040050 then do;
		warfarin=1; warfarin_dt=min(warfarin_dt,svcdate);
		if missing(warfarin_strength) then warfarin_strength = strngth; 
	end;
	else if therdtl=2012040016 then do;
		dabigatran=1; dabigatran_dt=min(dabigatran_dt,svcdate);
		if missing(dabigatran_strength) then dabigatran_strength = strngth;
	end;
	else if therdtl=2012040043 then do;
		rivaroxaban=1; rivaroxaban_dt=min(rivaroxaban_dt,svcdate);
		if missing(rivaroxaban_strength) then rivaroxaban_strength = strngth;
	end;
	else if therdtl=2012040012 then do;
		apixaban=1; apixaban_dt=min(apixaban_dt,svcdate);
		if missing(apixaban_strength) then apixaban_strength = strngth;
	end;
	else if therdtl = 2012040023 then do;
		edoxaban = 1; edoxaban_dt = min(edoxaban_dt,svcdate);
		if missing(edoxaban_strength) then edoxaban_strength = strngth;
	end;

	retain warfarin dabigatran rivaroxaban apixaban edoxaban
		warfarin_dt dabigatran_dt rivaroxaban_dt apixaban_dt edoxaban_dt 
		warfarin_strength dabigatran_strength rivaroxaban_strength apixaban_strength edoxaban_strength;

	drop svcdate therdtl ndcnum strngth;

	if last.enrolid then output;
run;

proc datasets library = work;
	delete meds meds2 redbook;
run;

* merge enrolment + af_dx + indicators/start date for OAC use;

proc sort data=enrolment2 nodupkey; by enrolid; run;
proc sort data=af_id nodupkey; by enrolid; run;
proc sort data=meds3 nodupkey; by enrolid; run;

data cohort;
	merge enrolment2 (in=w) af_id(in=v) meds3;
	by enrolid;

	age_af=year(afdate)-dobyr;

	if v and w;
run;

/*
data mscan.cohort2015_20170329; 
	set cohort;

	if warfarin_dt>enddt then do; warfarin_dt = .; warfarin = 0; warfarin_strength = ""; end;
	if dabigatran_dt > enddt then do; dabigatran_dt = .; dabigatran = 0; dabigatran_strength = ""; end;
	if rivaroxaban_dt > enddt then do; rivaroxaban_dt = .; rivaroxaban = 0; rivaroxaban_strength = ""; end;
	if apixaban_dt>enddt then do; apixaban_dt = .; apixaban = 0; apixaban_strength = ""; end;
	if edoxaban_dt>enddt then do; edoxaban_dt = .; edoxaban = 0; edoxaban_strength = ""; end;

	where startdt<=afdate<=enddt and 18<age_af<100;
run;

proc contents data = mscan.cohort2015_20170329; run;

proc freq data = mscan.cohort2015_20170329;
	table sex apixaban dabigatran rivaroxaban warfarin edoxaban;
run;

proc means data = mscan.cohort2015_20170329;
	var age_af;
run;

*/
