# Synthetic Population Generation with Public Health Characteristics for Spatial Agent-Based Models

This repository contains the code used for generating a synthetic population with public health surveys for the initialization of agent populations within spatial ABMs, as well as the data used to validate the synthesized vaccination uptake at the census tract level in Virginia for December 2021. The synthetic population is created by integrating spatially aggregated demographic data from the American Community Survey (ACS) with individual-level survey data on COVID-19 vaccine uptake. The method is adaptable to various spatial scales, time periods, and other health applications such as smoking and other protective behaviors.



### Data Sources

- **Census Tract Data**: We use 2021 ACS data for Virginia Census Tracts, focusing on individuals aged 18 and over. The demographic variables include gender, race, age, education, and income, which significantly influence COVID-19 vaccine uptake. The dataset excludes records with missing or zero values, resulting in 2162 records. The dataset can be obtained at differing aggregation levels and for various locations at https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-data.html. 

- **Local Survey**: This survey is representative of Virginia and includes data on demographics, beliefs, attitudes, and perceptions related to COVID-19 and protective behaviors. Collected by Climate Nexus Polling (August 15-31, 2021), the survey sample includes 3,528 respondents. The dataset is de-identified and available upon request. This project was approved by the George Mason University IRB (IRB 1684418-3).

- **Household Pulse Survey (HPS)**: A publicly available national survey from the US Census Bureau, focusing on the social and economic impacts of COVID-19. We use HPS Week 41 data, reducing the sample to 3,500 respondents to match the size of the local survey, adjusting the vaccination rate to 50% for alignment with Virginia data. More information and the obtained dataset is avaiable at https://www.census.gov/data/experimental-data-products/household-pulse-survey.html. 

### Validation

Validation is performed using CT-level vaccine uptake data for individuals aged 12+ in Virginia as of December 30, 2021. The data was acquired from the Virginia Department of Public Health and is not publicly available. After removing records with vaccine uptake greater than 100%, the validation focuses on 1592 CTs.

### Adaptability

This study and the associated code are designed to be adaptable across various spatial scales, time periods, and health applications. While this study focuses on COVID-19 vaccine uptake, the approach can be applied to other health-related behaviors such as smoking, physical activity, or other protective health behaviors. The flexibility of the IPF method ensures it can be tailored to different demographic variables, survey data, and geographic regions.


## Repository Contents

- **`POP_GEN_SCRIPT.R`**: This script contains the code used to generate a synthetic population based on various demographic and COVID-19 health-related variables. The method integrates individual attitudes and initial adoption of protective behaviors using public health survey data, making it applicable for various public health studies. This script also includes generating a synthetic population based on the null model. 

- **`Census_Tract_VA_Vaccine_Data.xlsx`**: This dataset includes vaccination uptake data for census tracts in Virginia for December 2021 and December 2022. It is used to validate and compare the synthetic population with real-world data.

## Usage

1. **Synthetic Population Generation**: 
   - The `POP_GEN_SCRIPT.R` script is designed to be run in R. It generates a synthetic population based on demographic distributions and health survey data.
   - Ensure that all necessary R packages are installed, and update file paths as needed.

2. **Vaccination Uptake Validation**:
   - The `Census_Tract_VA_Vaccine_Data.xlsx` file contains census tract-level vaccination data. This can be used for analysis and comparison with the generated synthetic population representative of Virginia.
   - The data includes fields for census tract IDs, vaccination uptake percentages for December 2021, and December 2022.


## Aknowledgments 
This research was funded by National Science Foundation (Award #230970 and #2109647).

## Contact

For any questions or further information, please contact Emma Von Hoene at evonhoen@gmu.edu.



