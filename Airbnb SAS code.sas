/* Step 1: Import the data into SAS using PROC IMPORT */
proc import datafile="/home/u63048824/DSCI519/Project/listings Shareef.csv" out=airbnb_data dbms=csv replace;
run;

/* Step 2: Fit a linear regression model using price as the dependent variable */
/* 2.a.i: Investigate the dependent variable - PRICE */
proc univariate data=airbnb_data;
  var price;
run;

/* 2.a.ii: Check for missing values in the price variable */
proc means data=airbnb_data nmiss;
  var price;
run;

/* 2.a.iii: Remove outliers and create a log-transformed price variable */
data airbnb_data_cleaned;
  set airbnb_data;
  if 30 <= price <= 750;
  price_log = log(price);
run;

proc univariate data=airbnb_data_cleaned;
  var price;
run;




/* 2.a.iv: Choose a transformation based on skewness level */
data airbnb_data_transformed_skewed;
  set airbnb_data_cleaned;
  price_log = log(price); /* Log transformation */
run;

/* Assess skewness of log-transformed variable */
proc univariate data=airbnb_data_transformed_skewed;
  var price_log;
  histogram / normal;
run;


PROC MEANS DATA=airbnb_data_transformed_skewed (KEEP = _NUMERIC_) N NMISS MIN MAX MEAN MEDIAN STD; 
RUN;



PROC CONTENTS NOPRINT DATA=airbnb_data_transformed_skewed (KEEP=_NUMERIC_ DROP=id latitude longitude Price Price_Log) OUT=var1 (KEEP=name);
RUN;
/* 2.b.i.1: Check for multicollinearity using correlation table */
proc corr data=airbnb_data_transformed_skewed noprint outp=corr_output;
  var accommodates bedrooms beds minimum_nights maximum_nights availability_30 availability_60 availability_90 availability_365
      number_of_reviews number_of_reviews_ltm number_of_reviews_l30d review_scores_rating review_scores_accuracy
      review_scores_cleanliness review_scores_checkin review_scores_communication review_scores_location review_scores_value
      reviews_per_month;
run;

/* Display correlation table */
proc print data=corr_output; 
run;

/* 2.b.i.2: Investigate multicollinearity using VIF */
proc reg data=airbnb_data_transformed_skewed;
  model price_log = accommodates bedrooms beds minimum_nights maximum_nights availability_30 availability_60 availability_90 availability_365
                    number_of_reviews number_of_reviews_ltm number_of_reviews_l30d review_scores_rating review_scores_accuracy
                    review_scores_cleanliness review_scores_checkin review_scores_communication review_scores_location review_scores_value
                    reviews_per_month / SELECTION=FORWARD VIF COLLIN;
run;




/* 2.b.i.2: Categorization - Collapse categorical levels */
/* Categorization of Property_Type variable */
data airbnb_data_categorized;
  set airbnb_data_transformed_skewed;

  /* Collapse Property_Type into fewer categories */
  if Property_Type in ('Apartment', 'House', 'Townhouse', 'Loft', 'Condominium') then
    Property_CAT = Property_Type;
  else if Property_Type in ('Houseboat', 'Resort', 'Tent', 'Serviced ap', 'Aparthotel', 'Hotel', 'Boat', 'Other', 'Boutique ho') then
    Property_CAT = 'Group 1';
  else Property_CAT = 'Group 2';

  /* can Update other variables as needed */
  if host_has_profile_pic = ' ' then host_has_profile_pic = 'f';
  if host_identity_verified = ' ' then host_identity_verified = 'f';
  if host_is_superhost = ' ' then host_is_superhost = 'f';

run;

/* Use PROC FREQ to check the number of unique values for each categorical variable */
proc freq data=airbnb_data_categorized;
  tables _character_ / nocol norow nopercent missing;
run;     

/* Use PROC MEANS to check for missing values in continuous variables */
proc means data=airbnb_data_categorized nmiss;
  var _numeric_;
run;




/*2.b.i.3: Impute missing values for bedrooms with the mean */
data airbnb_data_imputed;
  set airbnb_data_categorized;

  
  if missing(bedrooms) then bedrooms = mean_of_bedrooms;
run;


/*2.b.i.4: Feature Engineering */
data airbnb_data_engineered;
  set airbnb_data_imputed; 

  /* Create new variable: bedrooms_squared */
  bedrooms_squared = bedrooms**2;

  /* Create dummy variables for a specific variable  */
  if beds = 'Category1' then category1 = 1; else category1 = 0;
  if price = 'Category2' then category2 = 1; else category2 = 0;
run;

/* Standardizing Numeric Variables */
proc stdize data=airbnb_data_engineered out=airbnb_data_standardized method=std;
  var beds price; 
run;


/*2.b.ii.1: Create frequency tables for categorical variables */
proc freq data=airbnb_data_standardized;
  tables 
    neighbourhood_cleansed
    instant_bookable
    host_has_profile_pic
    host_identity_verified
    host_is_superhost
    host_response_time
    property_type
    room_type
    category1
    category2;
run;




data airbnb_data_collapsed;
  set airbnb_data_standardized;

  /* Collapse levels for 'neighbourhood_cleansed' */
  if neighbourhood_cleansed in ('District 1', 'District 2', 'District 3') then
    collapsed_neighbourhood = 'Group1';
  else if neighbourhood_cleansed in ('District 4', 'District 5', 'District 6') then
    collapsed_neighbourhood = 'Group2';
  else if neighbourhood_cleansed in ('District 7', 'District 8', 'District 9') then
    collapsed_neighbourhood = 'Group3';
  else if neighbourhood_cleansed in ('District 10', 'District 11', 'District 12') then
    collapsed_neighbourhood = 'Group4';
  else if neighbourhood_cleansed in ('District 13', 'District 14') then
    collapsed_neighbourhood = 'Group5';
  /* Add more conditions as needed */

  /* Continue with other variables and transformations as needed */
run;



data airbnb_data_collapsed;
  set airbnb_data_standardized;

  /* Collapse levels for 'instant_bookable' */
  if instant_bookable = 't' then
    collapsed_instant_bookable = 'Bookable';
  else if instant_bookable = 'f' then
    collapsed_instant_bookable = 'Not Bookable';
  else
    collapsed_instant_bookable = 'Unknown';

  /* Continue with other variables and transformations as needed */
run;




data airbnb_data_collapsed;
  set airbnb_data_standardized;

  /* Collapse levels for 'host_response_time' */
  if host_response_time in ('within an hour', 'within a few hours') then
    collapsed_response_time = 'Fast Response';
  else if host_response_time in ('within a day', 'a few days or more') then
    collapsed_response_time = 'Slow Response';
  else
    collapsed_response_time = 'Unknown';

  /* Continue with other variables and transformations as needed */
run;






data airbnb_data_collapsed;
  set airbnb_data_standardized;

  /* Collapse levels for 'property_type' */
  if property_type in ('Apartment', 'House', 'Townhouse', 'Condominium') then
    collapsed_property_type = 'Residential';
  else if property_type in ('Loft', 'Boutique hotel', 'Guesthouse', 'Serviced apartment') then
    collapsed_property_type = 'Unique Lodging';
  else
    collapsed_property_type = 'Other';

  /* Continue with other variables and transformations as needed */
run;





/* Split data into TRAIN and TEST datasets at an 80/20 split */
PROC SURVEYSELECT DATA=airbnb_data_collapsed SAMPRATE=0.20 SEED=42
  OUT=Full OUTALL METHOD=SRS;
RUN;






DATA TRAIN TEST;
  SET Full;
  IF Selected=0 THEN OUTPUT TRAIN; ELSE OUTPUT TEST;
  DROP Selected;
RUN;


%let lasso_var = log_accom log_bath log_guest log_min log_max log_avil30 
log_bedsper n_bronx n_brooklyn n_manhattan n_queens r_entire r_private 
h_super h_profile h_verified b_couch b_futon b_pullout b_real instant 
require_pic require_phone
hcount_level1 hcount_level2 hcount_level3 p_apart p_condo p_group2 p_house 
p_loft p_townhouse n_staten r_shared b_air p_group1 poly_accom poly_bath 
poly_guests poly_min poly_max poly_avail; 



PROC GLMSELECT DATA=airbnb_data_collapsed 
OUTDESIGN(ADDINPUTVARS)=reg_design 
PLOTS(stepaxis=normb)=all;
MODEL Price_Log=&lasso_var. / 
selection=lasso(stop=&k choose=SBC);
OUTPUT OUT = train_score;
SCORE DATA=TEST_FINAL PREDICTED RESIDUAL OUT=test_score;
run;

