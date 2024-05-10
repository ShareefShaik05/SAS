
/* Set up ODS PDF */
%let outpath = /home/u63048824/PG1/output; 
ods pdf file="&outpath/ClaimReports.pdf" style=Journal;
ods proclabel="";
options nodate;

/* Import the raw data file */
proc import datafile="/home/u63048824/PG1/data/TSAClaims2002_2017.csv"          
            out=claims_cleaned 
            dbms=csv
            replace;
            getnames=yes;
            guessingrows=max;
run;

/* Explore the data */

/* Preview the first 30 rows */
proc print data=work.claims_cleaned (obs=30);
run;

/* Explore the contents of the table*/
proc contents data=work.claims_cleaned varnum;
run;


proc freq data=work.claims_cleaned;
     tables Claim_Site 
            Disposition
            Claim_Type
            Date_Received
            Incident_Date / nocum nopercent;
     format Incident_Date Date_Received year4.;
run;

proc print data=work.claims_cleaned;
      where Date_Received < Incident_Date;
      format Date_Received Incident_Date date9.;
run;

/* Prepare the data */
/* 1) Remove entirely duplicated records */
proc sort data=work.claims_cleaned nodupkey; 
by _all_;
run;

/*2. Sort the data by ascending Incident_Date */

proc sort data=work.claims_cleaned;
 by Incident_Date;
run;

/* Replace missing and "-" values with Unknown */
data work.claims_cleaned;
    set work.claims_cleaned;
    if Claim_Type in ('-', ' ') then Claim_Type = 'Unknown';
    if Claim_Site in ('-', ' ') then Claim_Site = 'Unknown';
    if Disposition in ('-', ' ') then Disposition = 'Unknown';
run;

/*3. Clean the Claim_Site column */
data work.claims_cleaned;
    set work.claims_cleaned;
if Claim_Site in ('','-') then Claim_Site="Unknown";
run;
/*4. Clean the Disposition column */
data work.claims_cleaned;
    set work.claims_cleaned;
if Disposition in('','-') then Disposition="Unknown";
    else if Disposition = 'losed: Contractor Claim' then Disposition = 'Closed:Contractor Claim';
    else if Disposition = 'Closed: Canceled' then Disposition = 'Closed:Canceled';
run;
/*5. Clean the Claim_Type column */
data work.claims_cleaned;
    set work.claims_cleaned;
if Claim_Type in ('','-') then Claim_Type="Unknown";
    else if Claim_Type = 'Passenger Property Loss/Personal Injur' then Claim_Type='Passenger Property Loss';
    else if Claim_Type = 'Passenger Property Loss/Personal Injury' then Claim_Type='Passenger Property Loss';
    else if Claim_Type = 'Property Damage/Personal Injury' then Claim_Type='Property Damage';
run;
/*.6. All StateName values to proper case */
data work.claims_cleaned;
    set work.claims_cleaned;
    StateName = propcase(StateName);
run;

 /* All State values should be in uppercase  */    
data work.claims_cleaned;
    set work.claims_cleaned;
    State = upcase(State);
run;
/*7. Create a new column to indicate date issues */
data work.claims_cleaned;
    set work.claims_cleaned;
if (Incident_Date > Date_Received or 
     Date_Received =. or 
     Incident_Date =. or 
     year(Incident_Date) < 2002 or
     year(Incident_Date ) > 2017 or
     year(Date_Received ) < 2002 or 
     year(Date_Received ) > 2017) then Date_Issues="Needs Review";
run;

/*8. Add permanent labels and formats*/
data claims_raw;
     set claims_cleaned;
format Close_Amount dollar20.2 Date_Received Incident_Date date9.;
 
label Airport_Code = "Airport Code"
      Airport_Name = "Airport Name"
      Claim_Number = "Claim Number"
      Claim_Site = "Claim Site"
      Claim_Type = "Claim Type"
      Close_Amount = "Close Amount"
      Date_Issues = "Date Issues"
      Date_Received = "Date Received"
      Incident_Date = "Incident Date"
      Item_Category = "Item Category";
run;

/*9. Drop County and City */
data claims_raw;
     set claims_cleaned;
     drop county city;
run;

/*Report Requirements*/
/*1. How many data issues are in the overall data */ 

ods proclabel "Overall Date Issues";
title "Overall Date Issues in the Data";
proc freq data=work.claims_cleaned;
     table Date_Issues / missing nocum nopercent ;
run;
title;

/*2. How many claims per year of Incident_Date are in the overall data?*/

ods graphics on;
ods proclabel "Overall Claims by Year";
title "Overall Claims by Year";
proc freq data=work.claims_cleaned;
     table Incident_Date /nocum nopercent plots=freqplot;
     format Incident_Date year.;
     where Date_Issues is null;
run;
title;


ods pdf style=Journal;
/*3.*/
/*a. What are the frequency values for Claim_Type for the selected state?*/
/*b. What are the frequency values for Claim_Site for the selected state?*/
/*c. What are the frequency values for Disposition for the selected state?*/
ods proclabel "&statename Claims Overview";
title "&statename Claim Types, Claim Sites  and Disposition";
proc freq data=work.claims_cleaned order=freq;
table Claim_Type Claim_Site Disposition / nocum nopercent;
where StateName = "&statename" and Date_Issues is null;
run;
title;

ods pdf style=Journal;
/*d.What is the mean, minimum, maximum and sum of Close_Amount for the selected state? Rounded to the nearest integer.*/
ods proclabel "&statename Close Amount Statistics";
title "Close Amount Statistics for &statename";
proc means data=claims_cleaned min mean max sum maxdec=0;
  var Close_Amount;
  where StateName = "&statename" and Date_issues is null;
run;
title;


/* Close ODS PDF */
ods pdf close;




