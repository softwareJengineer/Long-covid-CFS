# Long-covid-CFS
Code to analyze DSQ responses to predict some feature.

We used this code to predict if an individual would meet the criteria for ME/CFS under the Institute of Medicine (IOM) criteria by using their DSQ responses recalling symptoms from the first two weeks of an acute COVID-19 infection.

# Main.R

## Variables

data_path: The path to the datafile holding the DSQ responses we want to analyze.

dependent_feature: What feature we want to predict, i.e. "IOM" or "CanadianDiagnosis". You may have to look at your dataset to find the exact column name of the feature you want to predict.

features: What features to use in our random forest model. Input a vector of column indices. For example, if we want to include "Feature1" and "Feature2" and have column indices 4 and 5 respectively, input c(4, 5). There are a few of these pre-created in the "required.R" file.

ntree: How many decision trees to use in the random forest algorithm. Higher takes longer and usually results in lower error rate. May take some adjustment to find the optimal value.

n_trials: How many trials to run of the final model.

binary: If we want symptoms to be presented in a binary measure. For example, if symptom 1 has a frequency and severity score, a binary measure of this would be if the symptom is present or not. Should be TRUE or FALSE.

threshold: Threshold for binarizing data. If a symptom's frequency and severity are both at or equal to this value, then it is labeled as being present.

balance: If we want to use random oversampling to balance the dataset. Will duplicate rows from the minority class and add them to the dataset until both classes are equal. For example, if the dataset has 5 CFS and 3 non-CFS rows, 2 of the non-CFS rows will be duplicated and added to the dataset. Should be TRUE or FALSE.

n_feature_range: Vector of how many features we want to create new models with to find the optimal number of features. For example, if we want to create models with 5, 10, and 15 features, input c(5, 10, 15).

## The code

### Part 1: Data Processing

Part 1 reads in the data, prunes it down to only include the features specified in the "features" variable, and binarizes and/or balances it if those to variables are set to TRUE. 

### Part 2: Sorting Features By Importance

Part 2 performs a leave one out cross-validation on the data and will calculate the mean decrease in Gini. A higher mean decrease in Gini indicates a higher importance of the feature to the model. Each feature has its mean decrease in Gini calculated and are sorted in descending order into the variable "sorted_feature_names".

### Part 3: Getting the Best \# of Features to Use in the Model

Part 3 performs leave one out cross-validation using varying numbers of the most important features, as specified in the "n_feature_range" variable. The overall accuracy, sensitivity, and specificity of each model is put into the dataframe "best_n_features".

### Part 4: Repeated Trials for Validation and Consistency

Part 4 selects the model with the best accuracy and performs n_trials of leave one out cross-validation on it. The results of each trial are put into the dataframe "all_trial_data".
