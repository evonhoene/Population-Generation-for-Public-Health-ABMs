# The R script for "Synthetic population generation for spatial agent-based models of infectious disease spread"  
# Code generated by: Emma Von Hoene
# Other authors on article: Amira Roess, Hamdi Kavak, Taylor Anderson
# Affiliation: George Mason University, Fairfax, VA, USA
# Contact: evonhoen@gmu.edu
# Adapted from: https://rpubs.com/robinlovelace/5089 ; https://www.taylorfrancis.com/books/mono/10.1201/9781315381640/spatial-microsimulation-robin-lovelace-morgane-dumont 
# Description: The script written to generate a synthetic population from public health surveys. 
# It is important to note that the data processing of the individual level survey and spatially aggregated datasets was completed prior to executing this script
# This code is adaptable for other researchers using other datasets to generate synthetic populations for various applications

########################## LOAD IN NEEDED R LIBARIES ######################################
library(readxl)
library(dplyr)
library(writexl)
library(tidyr)
library(ggplot2)
library(pscl)
library(readxl)

########################## READING IN INDIVIDUAL LEVEL SURVEY AND SPATIALLY AGGREGATED DATASETS ######################################

## --- Individual-level Public Survey Data --- ##
## This dataset was processed before this script, where each attribute category (e.g., gender: male and female) had a new binary column (e.g., male, female) was created for each category and filled accordingly

# Read in the individual-level health survey data from an Excel sheet
data <- read_excel("INSERT .xlsx file path HERE!")

# Selecting only attributes we are interested in 
# Examples: ID, gender, race, age, education... column names will be different based on how the survey data is processed, add other variables if needed
selected_data <- select(data, ID, male, female, race1, race2, race3, race4, Age1, Age2, Age3, Age4, n_bach, bach, Income1,	Income2,	Income3, Income4, vaccine)

# Convert matrix into a dataframe
selected_data <- data.frame(selected_data) 

# Setting up more descriptive column names
c.names <- c("id", "male", "female", "white", "black", "hispanic", "other", "age_18_29", "age_30_49","age_50_64", "age_65_plus", "no_bachelors", "bachelors",  "income_25k_u", "income_25_50k", "income_50_100k", "income_100k_p", "vaccine")

# Add correct column names (to better define)
names(selected_data) <- c.names 

# Changing datatypes -- all attribute columns should be numeric for the IPF process
selected_data[] <- lapply(selected_data, as.numeric)



## --- Spatially Aggregated Data --- ##
## This dataset was processed before this script, where the census data was grouped based on the categories determined from the individual level survey data

# Read in census tract data
census <- read_excel("INSERT .xlsx file path HERE!")

# Selecting only attributes we are interested in 
# Examples: ID, gender, race, age, education... column names will be different based on how the spatial data is processed, add other variables if needed
census_select <- select(census, GEOID, male, female, race1, race2, race3, race4, Age1, Age2, Age3, Age4, n_bach, bach, Income1,	Income2,	Income3, Income4)

# Convert matrix into a dataframe
census_select <- data.frame(census_select) 

# Changing values of 0 to 0.0001 for all attributes so that IPF works
census_select <- census_select %>%
  mutate_at(vars(-GEOID), ~ ifelse(. == 0, 0.000001, .))

########################## STRATIFIED SAMPLING OF INDIVIDUAL LEVEL SURVEY ######################################
# * this step is optional -- this was only conducted to address the 91% vaccination bias in the Household Pulse Survey
# * proceed to checking the total constraints if stratified sampling is not needed for the survey dataset


# Define the total number of records for the final sample (enter number of individual responses you want in the sample)
total_records <- 3500

# Split the survey data into vaccinated and unvaccinated groups
vaccinated_data <- selected_data %>% filter(vaccine == 1)
unvaccinated_data <- selected_data %>% filter(vaccine == 0)

# Calculate the number of records needed from each group to achieve 50% representation
vaccinated_count <- round(total_records * 0.50)
unvaccinated_count <- total_records - vaccinated_count

# Create the composite stratification variable for both groups (will need to change attribute names to match the survey data used)
vaccinated_data <- vaccinated_data %>%
  mutate(stratum = interaction(
    male, female, white, black, hispanic, other,
    age_18_29, age_30_49, age_50_64, age_65_plus,
    bachelors, no_bachelors,
    income_25k_u, income_25_50k, income_50_100k, income_100k_p,
    drop = TRUE
  ))

unvaccinated_data <- unvaccinated_data %>%
  mutate(stratum = interaction(
    male, female, white, black, hispanic, other,
    age_18_29, age_30_49, age_50_64, age_65_plus,
    bachelors, no_bachelors,
    income_25k_u, income_25_50k, income_50_100k, income_100k_p,
    drop = TRUE
  ))

# Calculate the size for each stratum in both groups
vaccinated_strata_counts <- vaccinated_data %>%
  group_by(stratum) %>%
  summarise(count = n()) %>%
  ungroup()

unvaccinated_strata_counts <- unvaccinated_data %>%
  group_by(stratum) %>%
  summarise(count = n()) %>%
  ungroup()

vaccinated_proportions <- vaccinated_strata_counts %>%
  mutate(proportion = count / sum(count))

unvaccinated_proportions <- unvaccinated_strata_counts %>%
  mutate(proportion = count / sum(count))

vaccinated_sample_size <- vaccinated_proportions %>%
  mutate(sample_count = round(proportion * vaccinated_count))

unvaccinated_sample_size <- unvaccinated_proportions %>%
  mutate(sample_count = round(proportion * unvaccinated_count))

# Ensure sample_count does not exceed the available records in any stratum
vaccinated_sample_size <- vaccinated_sample_size %>%
  mutate(sample_count = pmin(sample_count, count))

unvaccinated_sample_size <- unvaccinated_sample_size %>%
  mutate(sample_count = pmin(sample_count, count))

# Perform stratified sampling for both groups
sampled_vaccinated <- vaccinated_data %>%
  group_by(stratum) %>%
  group_split() %>%
  map_dfr(~ .x %>% sample_n(size = vaccinated_sample_size$sample_count[match(unique(.x$stratum), vaccinated_sample_size$stratum)], replace = FALSE))

sampled_unvaccinated <- unvaccinated_data %>%
  group_by(stratum) %>%
  group_split() %>%
  map_dfr(~ .x %>% sample_n(size = unvaccinated_sample_size$sample_count[match(unique(.x$stratum), unvaccinated_sample_size$stratum)], replace = FALSE))

# Combine the samples
sampled_data <- bind_rows(sampled_vaccinated, sampled_unvaccinated)

# Reform sampled data to fit original dataset format for IPF process
selected_data <- select(sampled_data, id, male, female, white, black, hispanic, other,age_18_29, age_30_49,age_50_64, age_65_plus, no_bachelors, bachelors, income_25k_u, income_25_50k, income_50_100k, income_100k_p, vaccine)

# Save the sampled survey to an Excel file
df <- as.data.frame(sampled_data)
write_xlsx(df, "INSERT .xlsx file path HERE!")


########################## CHECKING CONSTRAINTS PRIOR TO IPF ######################################

# ** Checking Individual level data (sum should equal number of individuals multiplied by total variables -- 
  # so if there are 3500 survey responses and 5 attribute categories (age, gender, race, education, income), then the total should be equal to 17,500

# Select all columns except the first ID column
data_excluding_first <- selected_data[, -1]

# Calculate the sum of each column
column_sums <- colSums(data_excluding_first, na.rm = TRUE)

# Sum the column sums to get the total
total_sum <- sum(column_sums)

# Print the total sum
print(total_sum)

# ** Checking spatially aggregated data
 # each geographic zone (e.g., census tract) should have the same amount of people; for example, census tract 1 should have a summed up population of 4,321 for each attribute

# Subset the first 10 rows and gender columns 
subset_gender <- census_select[1:10, 2:3]

# Calculate the sum of each row
row_sums_gender <- rowSums(subset_gender, na.rm = TRUE)

# Print the row sums
print(row_sums_gender)

# Subset the first 10 rows and race columns
subset_race <- census_select[1:10, 4:7]

# Calculate the sum of each row
row_sums_race <- rowSums(subset_race, na.rm = TRUE)

# Print the row sums
print(row_sums_race)

# Subset the first 10 rows and age columns
subset_age <- census_select[1:10, 8:11]

# Calculate the sum of each row
row_sums_age <- rowSums(subset_age, na.rm = TRUE)

# Print the row sums
print(row_sums_age)

# Subset the first 10 rows and education columns
subset_edu <- census_select[1:10, 12:13]

# Calculate the sum of each row
row_sums_edu <- rowSums(subset_edu, na.rm = TRUE)

# Print the row sums
print(row_sums_edu)

# Subset the first 10 rows and income columns
subset_inc <- census_select[1:10, 14:16]

# Calculate the sum of each row
row_sums_inc <- rowSums(subset_inc, na.rm = TRUE)

# Print the row sums
print(row_sums_inc)


########################## CREATING NECESSARY ARRAYS PRIOR TO IPF ######################################

## --- Create Weights  --- ##

# Creating one set of weights for each constraint and one for starting
# these will stay empty for now and will be used in future iterations
# for example, if there are 3500 responses in the survey and a total of 2198 geographic zones (e.g., census tracts) in the study area
# then, these weights will have 3500 rows for individuals, and 2198 columns for tracts

weights0 <- array(dim = c(nrow(selected_data), nrow(census_select)))
weights1 <- array(dim = c(nrow(selected_data), nrow(census_select)))
weights2 <- array(dim = c(nrow(selected_data), nrow(census_select)))
weights3 <- array(dim = c(nrow(selected_data), nrow(census_select)))
weights4 <- array(dim = c(nrow(selected_data), nrow(census_select)))
weights5 <- array(dim = c(nrow(selected_data), nrow(census_select)))

weights0[, ] <- 1  # sets initial weights to 1


## --- Create Survey Aggregate Arrays  --- ##

# Creating an array for spatially aggregate data
# for example, if there are a total of 2198 geographic zones (e.g., census tracts) in the study area, and there are 16 columns for each attribute category (e.g., gender will be male, female; race will be white, black, hispanic, other...)
# there are 2198 rows for each zone, 16 columns for each category of spatial data


cen.agg <- array(dim = c(nrow(census_select), ncol(census_select)-1))
cen.agg1 <- array(dim = c(nrow(census_select), ncol(census_select)-1))
cen.agg2 <- array(dim = c(nrow(census_select), ncol(census_select)-1))
cen.agg3 <- array(dim = c(nrow(census_select), ncol(census_select)-1))
cen.agg4 <- array(dim = c(nrow(census_select), ncol(census_select)-1))
cen.agg5 <- array(dim = c(nrow(census_select), ncol(census_select)-1))

########################## CONDUCTING IPF ITERATIONS  ######################################

## --- Calculate Aggregate Values based on  Individual-Level Data   --- ##

#  removing first columns from datasets so that ID attributes are not included in IPF procedure
census_select2 <- census_select[, -1]
selected_data2 <- selected_data[, -1]

## ******* RE-RUN IPF PROCESS FROM THIS POINT !!! ******* (ignore if you are just starting the IPF process)

# Iterate through each row of the spatial aggregate data 
for (i in 1:nrow(census_select2)) {
  
  # Calculates the aggregate values for the i-th row
  # Multiplies each column of the binary individual level data by the corresponding column in the i-th column of the weights0 array
  # Then sums up these values columnwise, resulting in aggregate values for each category
  # These aggregate values are assigned to the i-th row of the dataframe (USd.agg)
  
  # For example, for the first row of all.msim, 
  # the aggregate values are calculated by summing up the products of each column 
  # in USd.cat with the corresponding column in the first row of weights0
  
  cen.agg[i, ] <- colSums(selected_data2 * weights0[, i])
}


## --- Evaluating Results from First Iteration   --- ##

# creates a scatter plot comparing the model output 
plot(as.vector(as.matrix(census_select2)), as.vector(as.matrix(cen.agg)), xlab = "Constraints", 
     ylab = "Model output")
abline(a = 0, b = 1)

# Calculating correlation 
cor(as.vector(as.matrix(census_select2)), as.vector(as.matrix(cen.agg)))

################ CONSTRAINT 1: AGE ###################
## Adjusting weights based on ratios between individual-level and spatial aggregate data
## Then using the adjusted weights to  re-calculate the aggregate values 

# Iterate through each row of spatial aggregate data 
# For each row, we are aiming to calculate ratios between aggregate and individual-level data for each age group/range
for (j in 1:nrow(census_select2)) {
  # selects rows from an index where age in the survey data is the specified category (e.g., 18-29), 
  # then assigns values from retrieving value from the j-th row and 1st column of census data, 
  # then divides by the value from the j-th row and 1st column of the cen.agg data
  # make sure the attribute column names match from the "data" survey dataset and the index of the specified attribute is correct in the "census_select2" spatially aggregated dataset
  weights1[which(data$age1 == 1), j] <- census_select2[j, 7]/cen.agg[j, 7]
  weights1[which(data$age2 == 1), j] <- census_select2[j, 8]/cen.agg[j, 8]
  weights1[which(data$age3 == 1), j] <- census_select2[j, 9]/cen.agg[j, 9]
  weights1[which(data$age3 == 1), j] <- census_select2[j, 10]/cen.agg[j, 10]
}

# Iterate over each row of the spatial aggregate data to calculate aggregate values with adjusted weights by summing up the products 
for (i in 1:nrow(census_select2)) {
  cen.agg1[i, ] <- colSums(selected_data2 * weights0[, i] * weights1[, i])
}


## --- Evaluating Results from Second Iteration   --- ##
# creates a scatter plot comparing the model output 
plot(as.vector(as.matrix(census_select2)), as.vector(as.matrix(cen.agg1)), xlab = "Constraints", 
     ylab = "Model output")
abline(a = 0, b = 1)

# Calculating correlation 
cor(as.vector(as.matrix(census_select2)), as.vector(as.matrix(cen.agg1)))

################ CONSTRAINT 2: SEX ###################

# Iterate through each row of spatial aggregate data 
# For each row, we are aiming to calculate ratios between aggregate and individual-level data for each gender
for (j in 1:nrow(census_select2)) {
  # selects rows from an index where gender in the survey data is the specified category (e.g., male),
  # then assigns values from retrieving value from the j-th row and 4th column of census data, 
  # then divides by the value from the j-th row and 1st column of the cen.agg data
  # make sure the attribute column names match from the "data" survey dataset and the index of the specified attribute is correct in the "census_select2" spatially aggregated dataset
  weights2[which(data$male == 1), j] <- census_select2[j, 1]/cen.agg1[j, 1]
  weights2[which(data$female == 1), j] <- census_select2[j, 2]/cen.agg1[j, 2]
}

# Iterate over each row of the spatial aggregate data to calculate aggregate values with adjusted weights by summing up the products 
for (i in 1:nrow(census_select2)) {
  cen.agg2[i, ] <- colSums(selected_data2 * weights0[, i] * weights1[, i] * weights2[,i])
}

## --- Evaluating Results from Third Iteration   --- ##
# creates a scatter plot comparing the model output 
plot(as.vector(as.matrix(census_select2)), as.vector(as.matrix(cen.agg2)), xlab = "Constraints", 
     ylab = "Model output")
abline(a = 0, b = 1)

# Calculating correlation 
cor(as.vector(as.matrix(census_select2)), as.vector(as.matrix(cen.agg2)))

################ CONSTRAINT 3: RACE ###################

# Iterate through each row of spatial aggregate data 
# For each row, we are aiming to calculate ratios between aggregate and individual-level data for each race
for (j in 1:nrow(census_select2)) {
  # selects rows from an index where race in the survey data is the specified category (e.g., white),
  # then assigns values from retrieving value from the j-th row and 4th column of census data, 
  # then divides by the value from the j-th row and 1st column of the cen.agg data
  # make sure the attribute column names match from the "data" survey dataset and the index of the specified attribute is correct in the "census_select2" spatially aggregated dataset
  weights3[which(data$race1_I1 == 1), j] <- census_select2[j, 3]/cen.agg2[j,3]
  weights3[which(data$race1_I2 == 1), j] <- census_select2[j, 4]/cen.agg2[j,4]
  weights3[which(data$race1_I3 == 1), j] <- census_select2[j, 5]/cen.agg2[j,5]
  weights3[which(data$race1_I4 == 1), j] <- census_select2[j, 6]/cen.agg2[j,6]
}

# Iterate over each row of the spatial aggregate data to calculate aggregate values with adjusted weights by summing up the products 
for (i in 1:nrow(census_select2)) {
  cen.agg3[i, ] <- colSums(selected_data2 * weights0[, i] * weights1[, i] * weights2[,i]*weights3[,i])}

## --- Evaluating Results from fourth Iteration   --- ##
# creates a scatter plot comparing the model output 
plot(as.vector(as.matrix(census_select2)), as.vector(as.matrix(cen.agg3)), xlab = "Constraints", 
     ylab = "Model output")
abline(a = 0, b = 1)

# Calculating correlation 
cor(as.vector(as.matrix(census_select2)), as.vector(as.matrix(cen.agg3)))

################ CONSTRAINT 4: EDUCATION ###################

# Iterate through each row of spatial aggregate data 
# For each row, we are aiming to calculate ratios between aggregate and individual-level data for each education type
for (j in 1:nrow(census_select2)) {
  # selects rows from an index where education in the survey data is the specified category (e.g., no bachelors),
  # then assigns values from retrieving value from the j-th row and 4th column of census data, 
  # then divides by the value from the j-th row and 1st column of the cen.agg data
  # make sure the attribute column names match from the "data" survey dataset and the index of the specified attribute is correct in the "census_select2" spatially aggregated dataset
  weights4[which(data$n_bach == 1), j] <- census_select2[j, 11]/cen.agg3[j,11]
  weights4[which(data$bach == 1), j] <- census_select2[j, 12]/cen.agg3[j,12]
}

# Iterate over each row of the spatial aggregate data to calculate aggregate values with adjusted weights by summing up the products 
for (i in 1:nrow(census_select2)) {
  cen.agg4[i, ] <- colSums(selected_data2 * weights0[, i] * weights1[, i] * weights2[,i]*weights3[,i]*weights4[,i])}

## --- Evaluating Results from fifth Iteration   --- ##
# creates a scatter plot comparing the model output 
plot(as.vector(as.matrix(census_select2)), as.vector(as.matrix(cen.agg4)), xlab = "Constraints", 
     ylab = "Model output")
abline(a = 0, b = 1)

# Calculating correlation 
cor(as.vector(as.matrix(census_select2)), as.vector(as.matrix(cen.agg4)))

################ CONSTRAINT 5: INCOME ###################

# Iterate through each row of spatial aggregate data 
# For each row, we are aiming to calculate ratios between aggregate and individual-level data for each income level
for (j in 1:nrow(census_select2)) {
  # selects rows from an index where income level in the survey data is the specified category (e.g., less than 50,000$),
  # then assigns values from retrieving value from the j-th row and 4th column of census data, 
  # then divides by the value from the j-th row and 1st column of the cen.agg data
  # make sure the attribute column names match from the "data" survey dataset and the index of the specified attribute is correct in the "census_select2" spatially aggregated dataset
  weights5[which(data$Income1_I1 == 1), j] <- census_select2[j, 13]/cen.agg4[j,13]
  weights5[which(data$Income1_I2 == 1), j] <- census_select2[j, 14]/cen.agg4[j,14]
  weights5[which(data$Income1_I3 == 1), j] <- census_select2[j, 15]/cen.agg4[j,15]
}

# Iterate over each row of the spatial aggregate data to calculate aggregate values with adjusted weights by summing up the products 
weights6 <- weights0 * weights1 * weights2 * weights3 * weights4 * weights5
for (i in 1:nrow(census_select2)) {
  cen.agg5[i, ] <- colSums(selected_data2 * weights6[, i])}

## --- Evaluating Results from fifth Iteration   --- ##
# creates a scatter plot comparing the model output 
plot(as.vector(as.matrix(census_select2)), as.vector(as.matrix(cen.agg5)), xlab = "Constraints", 
     ylab = "Model output")
abline(a = 0, b = 1)

# Calculating correlation 
cor(as.vector(as.matrix(census_select2)), as.vector(as.matrix(cen.agg5)))

################ CHECKING TOTAL POPULATION MODELLED FOR EACH GEOGRAPHIC ZONE ###################

## constraint 1: gender
# Subset the first 10 rows and gender columns 
subset_gender <- cen.agg5[1:10, 1:2]

# Calculate the sum of each row
row_sums_gender <- rowSums(subset_gender, na.rm = TRUE)

# Print the row sums
print(row_sums_gender)

## Subset the first 10 rows and race columns
subset_race <- cen.agg5[1:10, 3:6]

# Calculate the sum of each row
row_sums_race <- rowSums(subset_race, na.rm = TRUE)

# Print the row sums
print(row_sums_race)

## Subset the first 10 rows and age columns
subset_age <- cen.agg5[1:10, 7:10]

# Calculate the sum of each row
row_sums_age <- rowSums(subset_age, na.rm = TRUE)

# Print the row sums
print(row_sums_age)

## Subset the first 10 rows and education columns
subset_edu <- cen.agg5[1:10, 11:12]

# Calculate the sum of each row
row_sums_edu <- rowSums(subset_edu, na.rm = TRUE)

# Print the row sums
print(row_sums_edu)

## Subset the first 10 rows and income columns
subset_inc <- cen.agg5[1:10, 13:15]

# Calculate the sum of each row
row_sums_inc <- rowSums(subset_inc, na.rm = TRUE)

# Print the row sums
print(row_sums_inc)

################ PERFORM ADDITIONAL IPF ITERATIONS ###################

## *** STOP HERE WHEN RUNNING THE IPF MODEL AGAIN !!! *** 

# Use results from initial results as starting point 
weights0 <- weights6
cen.agg.1 <- cen.agg 

## ** run the model again beginning from the first loop in the first iteration (check around line 258) and stop around line 477

############## VIEWING AND SAVING DATA ###########################

# iterating to breakdown of model fit by geogrpahic area with correlation
for (i in 1:nrow(census_select2)) {
  census_select2$cor[i] <- cor(as.vector(as.matrix(census_select2[i, 1:14])), cen.agg4[i, 
  ])
}

# Saving fractional weights/marginals generated by IPF to an Excel file (will be used in next steps of the script)
df <- as.data.frame(weights6)
write_xlsx(df, "Insert .xlsx file path HERE!")

################# INTEGERISATION ##############################
# Note: This step is computationally extensive, may need a cluster or will take longer to run

# Read in the marginals data 
marg <- read_excel("Insert .xlsx file path HERE!")

# Convert to matrix
matrix_mdf <- as.matrix(marg)

## Function to implement the TRS integerisation approach 
# Review these sources for more details on this approach: 
  # https://www.sciencedirect.com/science/article/pii/S0198971513000240
  # https://www.taylorfrancis.com/books/mono/10.1201/9781315381640/spatial-microsimulation-robin-lovelace-morgane-dumont

int_trs <- function(x){
  # converting to a vector
  xv <- as.vector(x) 
  # integer part of each weight is obtained by rounding down each element to the nearest integer
  xint <- floor(xv) 
  # decimal part of each weight is calculated by subtracting the integer part from the original weight vector
  r <- xv - xint 
  # the sum of all decimal parts is rounded to obtain an integer value representing the deficit population
  def <- round(sum(r)) 
  # random individuals are sampled with probabilities proportional to the decimal parts of their weights; 
  # these individuals represent the ones where weights need to be increased to reach the desired integer population
  topup <- sample(length(x), size = def, prob = r)
  # the weights are 'topped up' to reach the desired integer population, 
  # meaning that integer weights of the selected individuals are incremented by 1
  xint[topup] <- xint[topup] + 1
  # reshaping integer weights into a matrix
  dim(xint) <- dim(x)
  # dimension names are set to match those of the input
  dimnames(xint) <- dimnames(x)
  xint
}


## Applying the function to the matrix of marginals
result <- int_trs(matrix_mdf)

## Saving Integerisation results
df <- as.data.frame(result)
write_xlsx(df, "Insert .xlsx file path HERE!")

################# EXPANSION ##############################

# Read in the integers data
ints <- read_excel("Insert .xlsx file path HERE!")

# Convert to long data - reshapes the data so that each row represents a unique combination of an Individual's ID and a Geographic Zone (e.g., Census Tract) ID, with a count
long_data <- ints %>%
  pivot_longer(cols = -1, names_to = "CensusTractID", values_to = "Count") %>%
  rename(IndividualID = 1)

# Expand the data based on the counts - replicates rows based on the value in the Count column
expanded_data <- long_data %>%
  uncount(Count)

# Writing expansion results to a CSV sheet (too large for excel)
df <- as.data.frame(expanded_data)
write.csv(df, "INSERT .csv file path HERE!")

################ REPLICATING INDIVIDUALS AND SUMMARIZING VACCINE UPTAKE ################ 

# Read in the individual-level health survey data (if needed, should already be loaded in at the beginning of the code)
data <- read_excel("Insert .xlsx file path HERE!")

# Read in the expanded dataset (if needed)
expanded_data <- read.csv("Insert .csv file path HERE!")

# Joining the vaccine data (can bring over any attribute if interested) from the survey dataset to the expanded dataset (left join to keep all rows from expanded dataset)
merged_data <- left_join(expanded_data, 
                         select(data, ID, male, female, race1, race2, race3, race4, Age1, Age2, Age3, Age4, n_bach, bach, income1, income2, income3, income4, vaccine), 
                         by = c("IndividualID" = "ID"))

# Change columns to numeric as needed
merged_data[] <- lapply(selected_data, as.numeric)

# Writing replicated results to a csv sheet
df <- as.data.frame(merged_data)
write.csv(df, "Insert .csv file path HERE!")


# Summarize the vaccine data and demographic attributes by Geographic Zone (e.g., census tract) ID and counts the total synthetic population per zone (e.g., census tract)
summary_data <- merged_data %>%
  group_by(CensusTractID) %>%
  summarize(
    total_vaccine = sum(vaccine, na.rm = TRUE),
    total_male = sum(male, na.rm = TRUE),
    total_female = sum(female, na.rm = TRUE),
    total_white = sum(race1, na.rm = TRUE),
    total_black = sum(race2, na.rm = TRUE),
    total_hispanic = sum(race3, na.rm = TRUE),
    total_other = sum(race4, na.rm = TRUE),
    total_18_29 = sum(Age1, na.rm = TRUE),
    total_30_49 = sum(Age2, na.rm = TRUE),
    total_50_64 = sum(Age3, na.rm = TRUE),
    total_65o = sum(Age4, na.rm = TRUE),
    total_bach = sum(bach, na.rm = TRUE),
    total_n_bach = sum(n_bach, na.rm = TRUE),
    total_25k_under = sum(income1, na.rm = TRUE),
    total_25k_50k = sum(income2, na.rm = TRUE),
    total_50k_100k = sum(income3, na.rm = TRUE),
    total_100k_plus = sum(income4, na.rm = TRUE),
    total_population = n()
  )

# Writing joined and summed vaccine results to a Excel sheet
df <- as.data.frame(summary_data)
write_xlsx(df, "Insert .xlsx file path HERE!")

################# NULL MODEL: IMPOSING VACCINATION ON SIMULATED POPULATION #################

# Read in the individual-level health survey data (if needed)
data <- read_excel("Insert .xlsx file path HERE!")

# Read in the expanded dataset (if needed)
expanded_data <- read.csv("Insert .csv file path here!")

# Read in the real vaccine data (used to impose vaccination likelihood on agents)
real_vac <- read_excel("Insert .xlsx file path HERE!")

# Joining the vaccine data (can bring over any attribute if interested) from the survey dataset to the expanded dataset (left join to keep all rows from expanded dataset)
merged_data <- left_join(expanded_data, 
                         select(data, ID, male, female, race1, race2, race3, race4, Age1, Age2, Age3, Age4, n_bach, bach, income1, income2, income3, income4), 
                         by = c("IndividualID" = "ID"))

# Join replicated data with vaccine data (right join to include only records where there is available real vaccination data)
merged_data_vaccine <- merged_data %>%
  right_join(real_vac, by = "CensusTractID")

# Create a new column 'vaccine' and assigned based on the vaccination percentage likelihood imposed on to population of individuals 
set.seed(123)  # For reproducibility
merged_data_vaccine <- merged_data_vaccine %>%
  group_by(CensusTractID) %>%
  mutate(vaccine = rbinom(n(), 1, as.numeric(Real_Vax_Percent))) %>%
  ungroup()

# Writing imposed vaccine results to a CSV sheet
df <- as.data.frame(merged_data_vaccine)
write.csv(df, "Insert .csv file path HERE!")

################# JOINING SYNTHETICALLY POPULATED VACCINATION AND REAL VACCINATION DATA FOR VALIDATION ################# 

# Read in the real vaccine data for each geographic zone (e.g., census tract)
real_vac <- read_excel("Insert .xlsx file path HERE!")

# Read in the synthetic/simulated summarized vaccine results for each geographic zone (e.g., census tract)
sim_vac <- read_excel("C:Insert .xlsx file path HERE!")

# Performing a full join (all rows are preserved) between datasets
merged_data_full <- full_join(real_vac, sim_vac, by = "ID")


# Writing joined real and simulated vaccine results to a Excel sheet
df <- as.data.frame(merged_data_full)
write_xlsx(df, "Insert .xlsx file path HERE!")

## ** Scatterplots and additional evaluation metrics were calculated in Excel. 
## ** Mapping vaccine rates and clusters/outliers was done in ArcGIS Pro. 

################# PERFORMING A LOGISITIC REGRESSIONs ################# 

# Read in the individual-level health survey data 
data <- read_excel("Insert .xlsx file path HERE!")

# Fit the logistic regression model -- SURVEY DATA
ind_model <- glm(vaccine ~ male + white + age_65_plus + bachelors + 
                   income_25k_u, data = data, family = binomial)

# Summarize the model
summary(ind_model)

# obtain R-squared
pseudo_r2 <- pR2(ind_model)
print(pseudo_r2[4])

# Synthetic Population ----------------------------------------------------------

# Read in the synthetic population dataset
replicated_data <- read.csv("Insert .csv file path HERE!")

# Fit the logistic regression model -- SIMULATED/SYNTHETIC POPULATION
sim_model <- glm(vaccine ~ male + white + age_65_plus + bachelors + 
                   income_25k_u, data = replicated_data, family = binomial)

# Summarize the model
summary(sim_model)

# obtain R-squared
pseudo_r2 <- pR2(sim_model)
print(pseudo_r2[4])

# Null Model ----------------------------------------------------------

# Read in the IMPOSED synthetic population dataset
imposed_data <- read.csv("Insert .csv file path HERE!")

# Fit the logistic regression model -- SIMULATED/SYNTHETIC POPULATION with VACCINATION IMPOSED
imp_model <- glm(vaccine ~ male + white + age_65_plus + bachelors + 
                   income_25k_u, data = merged_data_vaccine, family = binomial)

# Summarize the model
summary(imp_model)

# obtain R-squared
pseudo_r2 <- pR2(imp_model)
print(pseudo_r2[4])
