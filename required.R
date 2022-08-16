# Created 8/12/2022
# Author: Jen Schwabe

# All the required functions and constants for running the code
# Should not have to look here

library(randomForest)
library(caret)
library(varImp)
library(arules)
library(ROSE)
library(dplyr)
library(openxlsx)
library(readxl)


############################# CONSTANTS


xsymptoms <- c(35:142)
xdomainscore <- seq(from = 315, to = 329, by = 2)
xdomaincomposite <- seq(from = 316, to = 330, by = 2)
xscore <- seq(from = 333, to = 439, by = 2)
xcomposite <- seq(from = 334, to = 440, by = 2)
xsleep <- c(333, 335, 337, 339, 341, 405)
xpem <- c(343, 347, 349, 351, 353, 439)
ximmune <- c(369, 371, 373, 375, 415)
xortho <- c(395, 397, 399, 401, 403, 417)
xneurocog <- c(355, 357, 359, 361, 363, 365, 367, 407, 409, 423, 427, 435, 437)
possible_labels <- c(0, 1)

#' The following are the top symptoms our models calculated.

top_8xcomposite_balanced <- c("xFatigueComposite", "xMentalComposite", "xUnrefreshedComposite",
                               "xMinimumComposite", "xSorenessComposite", "xNapComposite", 
                               "xHeavyComposite", "xHotComposite")


top_8xsymptoms_binary <- c("fatigue13", "mental16", "unrefreshed19", "minimum17", 
                            "soreness15", "nap20", "heavy14", "hot58")


############################ FUNCTIONS


#' Creates a formula object from column names and the index of
#' the data we want to predict
#' @param columns: the column names
#' @param target_index: the index of the data we are trying to predict
#' @return: the formula
create_formula <- function(columns, target_index) {
  # get the name of the value we are trying to predict
  target <- columns[target_index]
  # get the names of the features
  features <- columns[-target_index]
  # create the formula name
  formula <- paste(target, "~",
                   paste(features, sep = "", collapse = "+"),
                   sep = "", collapse = NULL)
  formula <- as.formula(formula)
  return(formula)
}

#' Uses the predicted labels and actual labels to give accuracy, sensitivity,
#' specificity, false positive rate. Works for binary classes only
#' @param actual: the actual labels
#' @param predicted: the predicted labels
#' @return: a list with the accuracy, sensitivity, specificity, false positive rate
analyze_labels <- function(actual, predicted) {
  tp <- 0
  fp <- 0
  tn <- 0
  fn <- 0
  for (i in 1:length(actual)) {
    if (actual[i] == 0 && predicted[i] == 0) {
      tn <- tn + 1
    } else if (actual[i] == 0 && predicted[i] == 1) {
      fp <- fp + 1
    } else if (actual[i] == 1 && predicted[i] == 0) {
      fn <- fn + 1
    } else {
      tp <- tp + 1
    }
  }
  acc <- (tp + tn) / (tp + tn + fp + fn)
  sens <- max(tp / (tp + fn), 0)
  spec <- max(tn / (tn + fp), 0)
  return(list("accuracy" = acc, "sensitivity" = sens, "specificity" = spec))
}

#' Creates a dataframe from the selected features and the dependent feature.
#' @param all_data: the entire dataframe
#' @param features: a vector of the column indices to select as features
#' @param dependent_feature: the name of the dependent feature
select_data <- function(all_data, features, dependent_feature) {
  if (is.numeric(features)) {
    data <- all_data[, colnames(all_data)[features]]
  } else {
    data <- select(all_data, features)
  }
  data[is.na(data)] <- -1
  data[data=="NA"] <- -1
  data <- cbind(data, all_data[dependent_feature])
  target_index <- ncol(data)
  data <- data[complete.cases(data[target_index]),]
  return(data)
}

#' Given two columns of frequency and severity values, tells whether or not the
#' symptom is classified as present or not (1 or 0)
#' @param frequency: the frequency column
#' @param severity: the severity column
#' @param threshold: the threshold at which to classify as present or not
#' @return: a list of the name of the symptom and whether or not it is present
check_present <- function(frequency, severity, threshold) {
  name <- names(frequency)[1]
  name <- substr(name, 2, nchar(name) - 1)
  f <- unlist(unname(frequency))
  s <- unlist(unname(severity))
  present <- ifelse(f >= threshold & s >= threshold, 1, 0)
  return(list("Name" = name, "Present" = present))
}

#' Takes a dataframe and binarizes frequency and severity of symptoms based on some threshold
#' @param all_data: the dataframe to binarize
#' @param start: the column index to start binarizing at
#' @param stop: the column index to stop binarizing at
#' @param threshold: the threshold at which to classify as present or not
#' @return: the binarized dataframe
binarize_data <- function(all_data, start, stop, threshold) {
  data_binary <- data.frame(matrix(nrow=nrow(all_data)))
  for (i in seq(from=start, to=stop, by=2)) {
    newcol <- check_present(all_data[i], all_data[i+1], threshold)
    name <- newcol$Name
    vals <- newcol$Present
    data_binary[[name]] <- vals
  }
  data_binary[1] <- NULL
  if (stop < ncol(all_data)) {
    for (i in (stop + 1):ncol(all_data)) {
      data_binary <- cbind(data_binary, all_data[i])
    }
  }
  return(data_binary)
}

#' Creates a random forest classification model based on some training data
#' and tests it
#' currently only works with one row of test data
#' @param train_data: the training data to base the model on
#' @param test_data: the data to test the model on
#' @param target_index: the column index of the data to predict
#' @param ntree: how many trees to use
#' @return: the predicted label and the actual label of the test row
rand_forest_classify <- function(train_data, test_data, target_index, formula, ntree=500) {
  n_features <- ncol(train_data) - 1
  # run the random forest algorithm
  rf <- randomForest(formula = formula, data = train_data,
                     ntree = ntree, mtry = n_features)
  # use the random forest model to predict the test data target's labels
  pr <- predict(rf, test_data)
  imp <- as.data.frame(importance(rf))[[1]]
  return(list("pr" = pr[[1]], "actual" = test_data[[target_index]], "importance" = imp))
}

#' Performs random forest on some data using leave one out cross-validation
#' Stands for leave one out cross-validation random forest classification
#' @param data: the dataset
#' @param target_index: the value we are trying to predict
#' @param ntree: number of decision trees
#' @param possible_labels: the possible labels the prediction can be
#' @return: a vector of the predicted labels and an importance dataframe
LOOCV_rfc <- function(data, target_index, ntree=500, possible_labels=c(0, 1)) {
  labels <- unlist(data[target_index])
  data[, target_index] <- as.factor(data[, target_index])
  formula <- create_formula(colnames(data), target_index)
  importance <- data.frame(matrix(ncol=ncol(data[-target_index])))
  colnames(importance) <- colnames(data[-target_index])
  pr_labels <- c()
  
  for (i in 1:nrow(data)) {
    # separate train and test data
    print(i)
    train_data <- data[-i,]
    test_data <- data[i,]
    train_labels <- labels[-i]
    # do the randomforest algorithm
    rf <- rand_forest_classify(train_data, test_data, target_index, formula, ntree)
    pr <- rf$pr
    pr_labels <- append(pr_labels, pr)
    imp <- rf$importance
    importance[(nrow(importance)+1),] <- imp
  }
  importance <- importance[-1,]
  importance <- colSums(importance)
  return(list("predicted" = pr_labels, "importance" = importance))
}

#' Calculates t-test for bivariate model
#' @param e1: error rate of model 1
#' @param e2: error rate of model 2
#' @param n1: number of instances in test set A
#' @param n2: number of instances in test set A
#' @return: p value
t_test <- function(e1, e2, n1, n2) {
  q <- (e1 + e2) / 2
  numerator <- abs(e1 - e2)
  denom <- (q * (1 - q)) * ((1 / n1) + (1 / n2))
  denom <- denom ^ .5
  p_val <- numerator / denom
  return(p_val)
}

#' Uses a grid search to get the best mtry in a random forest algorithm with the
#' given data
#' @param data: the data to get the best mtry of
#' @return: the best mtry
get_best_mtry <- function(data) {
  data[, target_index] <- as.factor(data[, target_index])
  control <- trainControl(method="repeatedcv", number=10, repeats=3, search="grid")
  tunegrid <- expand.grid(.mtry=c(1:(ncol(data) - 1)))
  rf_gridsearch <- train(IOM ~ ., data=data, method="rf", metric="Accuracy", tuneGrid=tunegrid, trControl=control)
  return(rf_gridsearch$bestTune[["mtry"]])
}
