# Long-covid-CFS

Code to analyze DSQ responses to predict some measure. Uses a machine learning model with random forests. Each trial uses a leave one out cross-validation procedure.

Running the whole code will order features by importance, find the number of features to use in a model that will most accurately predict the measure, and perform 30 trials using the model with that number of features. You can comment out later sections of the code (described below) to get only the feature importance order or the number of features that will result in the most accurate model.

We used this code to predict if an individual would meet the criteria for ME/CFS under the Institute of Medicine (IOM) criteria by using their DSQ responses recalling symptoms from the first two weeks of an acute COVID-19 infection.

# Main.R

## Variables

data_path: The path to the datafile holding the DSQ responses to analyze.

dependent_feature: What feature to predict, i.e. "IOM" or "CanadianDiagnosis". You may have to look at your dataset to find the exact column name of the feature you want to predict.

features: What features to use in the random forest model. Input a vector of column indices. For example, to include "Feature1" and "Feature2" that have column indices 4 and 5 respectively, input c(4, 5). There are a few of these pre-created in the "required.R" file.

ntree: How many decision trees to use in the random forest algorithm. Higher takes longer and usually results in lower error rate. May take some adjustment to find the optimal value.

n_trials: How many trials to run of the final model.

binary: If symptoms will be presented in a binary measure. For example, if symptom 1 has a frequency and severity measure, a binary measure would be if the symptom is present or not. Should be TRUE or FALSE.

threshold: Threshold for binarizing data. If a symptom's frequency and severity are both at or equal to this value, then it is labeled as being present.

balance: If random oversampling should be used to balance the dataset. Will duplicate rows from the minority class and add them to the dataset until both classes are equal. For example, if the dataset has 5 CFS and 3 non-CFS rows, 2 of the non-CFS rows will be duplicated and added to the dataset. Should be TRUE or FALSE.

n_feature_range: Vector of how many features to create new models with to find the optimal number of features. For example, to create models with 5, 10, and 15 features, input c(5, 10, 15).

## The code

### Part 1: Data Processing

Part 1 reads in the data, prunes it down to only include the features specified in the "features" variable, and binarizes and/or balances it if those to variables are set to TRUE. DO NOT COMMENT THIS SECTION OUT.

### Part 2: Sorting Features By Importance

Part 2 performs a leave one out cross-validation on the data and will calculate the mean decrease in Gini. A higher mean decrease in Gini indicates a higher importance of the feature to the model. Each feature has its mean decrease in Gini calculated and are sorted in descending order into the variable "sorted_feature_names".

### Part 3: Getting the Best \# of Features to Use in the Model

Part 3 performs leave one out cross-validation using varying numbers of the most important features, as specified in the "n_feature_range" variable. The overall accuracy, sensitivity, and specificity of each model is put into the dataframe "best_n_features".

### Part 4: Repeated Trials for Validation and Consistency

Part 4 selects the model with the best accuracy and performs n_trials of leave one out cross-validation on it. The results of each trial are put into the dataframe "all_trial_data".

# Required.R

## Constants

Includes some useful column indices of the dataset, such as the column indices for all the initial symptom composite scores. It also includes the names of the top eight symptom composite scores and binary score measures we used in our results. 

## Functions

Functions necessary for running the code in "Main.R". Descriptions are included in the code, but these shouldn't have to be changed.
