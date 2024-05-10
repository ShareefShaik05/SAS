/*1*/
FILENAME REFFILE '/home/u63048824/DSCI519/Final Project/listings Shareef.csv';
PROC IMPORT DATAFILE=REFFILE
DBMS=CSV
OUT= Listings;
GETNAMES=YES;
RUN;

PROC CONTENTS DATA=Listings; 
RUN;
/*2.a*/
PROC UNIVARIATE DATA=Listings; 
VAR Price; 
HISTOGRAM; 
RUN;


/* 2.a.i: Check for missing values in the price variable */
proc means data=Listings nmiss;
  var price;
run;


/*2.a.ii Eliminate outliers and create log transformed price variable */
DATA Listings_Price;
SET Listings;
WHERE 30 le Price le 750;
Price_Log = LOG(Price);
RUN;

proc univariate data=Listings_Price;
  var price;
run;

/*iv*/
proc univariate data=Listings_Price;
  var Price_Log;
  histogram;
run;

proc means data=Listings_Price n mean std skewness kurtosis;
  var Price_Log;
run;


/*2.b.i*/

/*Numeric Variables*/
PROC MEANS DATA=Listings_Price (KEEP = _NUMERIC_) N NMISS MIN MAX MEAN MEDIAN STD; 
RUN;

/* Use PROC REG to calculate VIF */
proc reg data=Listings_Price;
  model Price_Log = latitude longitude accommodates bedrooms beds 
                    minimum_nights maximum_nights availability_30 
                    availability_60 availability_90 availability_365 
                    number_of_reviews number_of_reviews_ltm 
                    number_of_reviews_l30d review_scores_rating 
                    review_scores_accuracy review_scores_cleanliness 
                    review_scores_checkin review_scores_communication 
                    review_scores_location review_scores_value 
                    reviews_per_month / vif;
run;


PROC CONTENTS NOPRINT DATA=Listings_Price (KEEP=_NUMERIC_ DROP=id latitude longitude Price Price_Log) OUT=var1 (KEEP=name);
RUN;



PROC SQL NOPRINT;
SELECT name INTO:varx separated by " " FROM var1;
QUIT;
%PUT &varx;
/* Create correlation analysis */
PROC CORR DATA=Listings_Price;
VAR &varx.;
RUN;

PROC REG DATA=Listings_Price PLOTS=ALL;
model Price_Log= &varx / 
selection=forward VIF COLLIN;
RUN;


proc freq data=Listings_Price;
  tables latitude / nocum nopercent;
run;


/*categorization*/
proc print data=Listings_Price(obs=20); /* Display the first 10 observations for inspection */
  var VAR37 - VAR61 description has_availability
      host_acceptance_rate host_response_rate host_response_time
      instant_bookable name neighborhood_overview neighbourhood_cleansed
      property_type room_type;
run;

/* Clean text variables */
data Listings_cleaned;
  set Listings_Price;

  /* Replace 'ProblematicVariable' with the actual variable name */
  description = prxchange('s/<[^>]*>//', -1, description);
  name = prxchange('s/<[^>]*>//', -1, name);
  

run;

/* Print a few rows of cleaned data */
proc print data=Listings_Price(obs=5);
run;


/* Create a new dataset with collapsed categorical levels */
DATA COLLAPSED_DATA;
    SET Listings_Price; 

    /* Collapse levels for neighbourhood_cleansed */
    IF neighbourhood_cleansed in ('District 1', 'District 2', 'District 3') THEN Neighbourhood_Group = 'Group 1';
    ELSE IF neighbourhood_cleansed in ('District 4', 'District 5', 'District 6') THEN Neighbourhood_Group = 'Group 2';
    ELSE Neighbourhood_Group = 'Other';

    /* Collapse levels for property_type */
    IF property_type in ('Apartment', 'House', 'Townhouse', 'Loft', 'Condominium') THEN Property_Category = 'Residential';
    ELSE IF property_type in ('Houseboat', 'Resort', 'Tent', 'Serviced ap', 'Aparthotel', 'Hotel', 'Boat', 'Other', 'Boutique ho') THEN Property_Category = 'Special';
    ELSE Property_Category = 'Other';

    /* Collapse levels for host_response_time */
    IF host_response_time in ('within an hour', 'within a few hours') THEN Response_Category = 'Quick';
    ELSE IF host_response_time in ('within a day', 'a few days or more') THEN Response_Category = 'Moderate';
    ELSE Response_Category = 'Unknown';
    DROP neighbourhood_cleansed property_type host_response_time; 
RUN;

/* Check for missing values in continuous variables */
proc means data=Listings_Price nmiss;
  var latitude longitude accommodates bedrooms beds 
      minimum_nights maximum_nights availability_30 
      availability_60 availability_90 availability_365 
      number_of_reviews number_of_reviews_ltm 
      number_of_reviews_l30d review_scores_rating 
      review_scores_accuracy review_scores_cleanliness 
      review_scores_checkin review_scores_communication 
      review_scores_location review_scores_value 
      reviews_per_month Price_Log;
run;

/* Check for missing values in continuous variables */
DATA Missing_Check;
    SET COLLAPSED_DATA; 
    IF MISSING(beds) THEN Missing_beds = 1;
    Total_Missing = sum(of Missing_beds);
RUN;

/* Summarize the count of missing values */
PROC MEANS DATA=Missing_Check NMISS;
    VAR Missing_beds;
RUN;

/* Impute missing_beds with mean */
PROC STANDARD DATA=Missing_Check OUT=Dataset MEAN=0 STD=1;
    VAR Missing_beds;
RUN;


/* Feature Engineering */
DATA Price_Featured;
    SET Missing_Check;

    /* Creating higher-order terms or polynomials */
    poly_accom = accommodates**2;
    poly_bath = bathrooms**2;
    poly_guests = guests_included**2;
    poly_min = minimum_nights**2;
    poly_max = maximum_nights**2;
    poly_avail = availability_30**2;

    /* Standardizing numeric variables */
    
    standardized_accom = (accommodates - mean_accom) / std_accom;
    standardized_bath = (bathrooms - mean_bath) / std_bath;
RUN;

/* Visualization: Scatter Plots */
PROC SGPLOT data=Price_Featured;
    scatter x=accommodates y=Price;
    title "Scatter Plot: Accommodates vs. Dependant variable";
RUN;


/* Display information about variables in the dataset */
PROC CONTENTS data=Price_Featured varnum;
RUN;


/* Creating frequency tables for categorical variables */
PROC FREQ data=Price_Featured;
TABLES room_type has_availability instant_bookable VAR37-VAR61
      Neighbourhood_Group Property_Category Response_Category;
RUN;

/* Check for missing values in variables VAR37 to VAR61 */
proc freq data=Price_Featured;
  tables VAR37-VAR61 / missing;
run;

/* Collapse Neighbourhood_Group into fewer groups */
data Price_Featured;
  set Price_Featured;
  if Neighbourhood_Group in ('Group 1', 'Group 2') then
    Neighbourhood_Group = 'Group 1-2';
run;


/* Split data into TRAIN and TEST datasets at an 80/20 split */
PROC SURVEYSELECT DATA=Price_Featured OUT=Full OUTALL SAMPRATE=0.20 SEED=42 METHOD=SRS;
RUN;

/* Create the TRAIN and TEST Data Sets */
DATA TRAIN TEST;
   SET Full;
   IF Selected=0 THEN OUTPUT TRAIN;
   ELSE OUTPUT TEST;
   DROP Selected;
RUN;




/*Regression*/

ods noproctitle;
ods graphics / imagemap=on;
PROC GLMSELECT DATA=Train 
OUTDESIGN(ADDINPUTVARS)=reg_design 
PLOTS(unpack)=all;
MODEL Price_Log=&varx. / 
selection=lasso(stop=10 choose=SBC);
*OUTPUT OUT = train_score;
SCORE DATA=Test PREDICTED RESIDUAL OUT=test_score;
run;



/*Decision Tree*/

%let tree_char = Neighbourhood_Group Property_Category Response_Category  room_type; 
%let tree_num = accommodates availability_30 availability_60 availability_90 availability_365 bedrooms beds latitude longitude maximum_nights minimum_nights number_of_reviews number_of_reviews_l30d number_of_reviews_ltm poly_accom poly_avail poly_max poly_min price review_scores_accuracy review_scores_checkin review_scores_cleanliness review_scores_communication review_scores_location review_scores_rating review_scores_value reviews_per_month; /* Add other numeric variables as needed */ ;

OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
ODS GRAPHICS ON;
%let path=/home/u63048824/DSCI519/Assignments/project final;
proc hpsplit data=train seed=66;
	class &tree_char.;
	Model Price_Log = &tree_char. &tree_num.;
	partition fraction(validate=0.3 seed=66);
	output out=hpsplout;
	code file="&path./hpsplexc.sas";
run;
ODS GRAPHICS OFF;
OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;


data score;
	set test;
	%include "&path./hpsplexc.sas";
run;


/*Random Forest*/
proc hpforest data=TRAIN
   maxtrees=500 vars_to_try=7
   seed=66 trainfraction=0.6
   maxdepth=20 leafsize=6
   alpha=0.1;
   target price_log / level=interval;
   input &tree_num. / level=interval;
   input &tree_char. / level=nominal;
   save file="&path./rfmodel_fit.bin";
run;


proc hp4score data=score;
	id Price_Log;
	score file="&path./rfmodel_fit.bin"
	out=score;
run;