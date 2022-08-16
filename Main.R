# Created 7/18/2022
# MedIX REU 2022
# Authors: Jen Schwabe

source("required.R")

############################# EXPERIMENT PARAMETERS ############################

#' The path to the datafile holding the DSQ responses we want to analyze.
data_path <- "./299_Dataset.xlsx"

#' What feature we want to predict.
dependent_feature <- "IOM"

#' What features to use in our random forest model. Input a vector of column 
#' indices. For example, if we want to include "Feature1" and "Feature2" and
#' have column indices 4 and 5 respectively, input c(4, 5).
#' There are a few of these pre-created in the "required.R" file.
features <- xcomposite

#' How many decision trees to use in the random forest algorithm. Higher takes
#' longer and usually results in lower error rate. May take some adjustment to
#' find the optimal value.
ntree <- 1500

#' How many trials to run of the final model.
n_trials <- 30

#' If we want symptoms to be presented in a binary measure. For example, if
#' symptom 1 has a frequency and severity score, a binary measure of this would
#' be if the symptom is present or not.
binary <- FALSE

#' Threshold for binarizing data. If a symptom's frequency and severity are both 
#' at or equal to this value, then it is labeled as being present.
threshold <- 2

#' If we want to use random oversampling to balance the dataset. Will duplicate
#' rows from the minority class and add them to the dataset until both classes
#' are equal. For example, if the dataset has 5 CFS and 3 non-CFS rows, 2 of the
#' non-CFS rows will be duplicated and added to the dataset. 
balance <- TRUE

#' Vector of how many features we want to create new models with to find the
#' optimal number of features. For example, if we want to create models with
#' 5, 10, and 15 features, input c(5, 10, 15).
n_feature_range <- c(3:15)


############################### CODE ###########################################

####################### PART 1: DATA PROCESSING ################################


# Reads in the data and cuts down the dataset to the features specified above
all_data <- read_excel(data_path)
data <- select_data(all_data, features, dependent_feature)
target_index <- ncol(data)
actual <- unlist(data[target_index])
balance_size <- as.numeric(max(table(data[[target_index]])) * 2)
rm(all_data)

data[, target_index] <- as.factor(data[, target_index])

# If binary is true, will merge a symptom's frequency and severity scores into
#a binary measure, with 1 being present and 0 being not present
if (binary) {
  data <- binarize_data(data, 1, ncol(data)-1, threshold)
  target_index <- ncol(data)
}

# If balance is true, will balance the dataset to have an equal number of CFS
# participants and not CFS participants (using random oversampling)
if (balance) {
  balanced_data <- ovun.sample(formula=formula, data=data, method = "over", 
                               N = balance_size)$data
  formula <- create_formula(colnames(data), target_index)
  target_index <- ncol(balanced_data)
  actual <- unlist(balanced_data[target_index])
}


#################### PART 2: SORTING FEATURES BY IMPORTANCE ####################


# Performs an initial leave-one-out cross-validation algorithm using random 
# forests to get the importance of each feature, then sorts the features
if (!balance) {
  model1 <- LOOCV_rfc(data, target_index, ntree, possible_labels)
} else {
  model1 <- LOOCV_rfc(balanced_data, target_index, ntree, possible_labels)
}

# Sorts the names of the features by importance
sorted_feature_names <- names(sort(model1$importance, decreasing=TRUE))


######### PART 3: GETTING THE BEST # OF FEATURES TO USE IN THE MODEL ###########


# Loops through each number of features specified in n_feature_range using 
# random forest leave one out cross-validation to get the best number of features
best_n_features <- data.frame(Accuracy=double(), Sensitivity=double(),
                              Specificity=double())
for (n in n_feature_range) {
  print(n)
  top_n_features <- head(sorted_feature_names, n=n)

  if (!balance) {
    new_data <- select_data(data, top_n_features, dependent_feature)
  } else {
    new_data <- select_data(balanced_data, top_n_features, dependent_feature)
  }
  target_index <- ncol(new_data)

  model2 <- LOOCV_rfc(new_data, target_index, ntree, possible_labels)
  al <- analyze_labels(actual, model2$predicted)
  best_n_features[n,] <- c(al$accuracy, al$sensitivity, al$specificity)
}

# Gets the best number of features, the names of the best features, and shrinks
# the dataset using only these features.
n_features <- which.max(best_n_features$Accuracy)
top_n_features <- head(sorted_feature_names, n=n_features)


########### PART 4: REPEATED TRIALS FOR VALIDATION AND CONSISTENCY #############


# Creates a new dataset using the number of features that had the best accuracy
new_data <- select_data(data, top_n_features, dependent_feature)
target_index <- ncol(new_data)

# Performs n_trials using the new dataset and a random forest algorithm with
# leave one out cross-validation procedure
all_trial_data <- data.frame(Accuracy=double(), Sensitivity=double(), 
                             Specificity=double())
for (i in 1:n_trials) {
  print(i)
  if (balance) {
    balanced_data <- ovun.sample(formula=formula, data=new_data, 
                                 method = "over", N = balance_size)$data
    actual <- unlist(balanced_data[target_index])
    model2 <- LOOCV_rfc(balanced_data, target_index, ntree, possible_labels)
  } else {
    model2 <- LOOCV_rfc(new_data, target_index, ntree, possible_labels)
  }
  
  al <- analyze_labels(actual, model2$predicted)
  all_trial_data[i,] <- c(al$accuracy, al$sensitivity, al$specificity)
}
