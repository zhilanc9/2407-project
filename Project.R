# ======================== Load Libraries ==========================================================

library(data.table)
library(car)
library(ggplot2)
library(caTools)
library(rpart)
library(rpart.plot)
library(randomForest)
library(earth)
library(caret)
library(mltools)
library(dplyr)
library(knitr)
library(ROSE)
library(pROC)


#explain the variables for those ambiguously named columns
##ATTRITION	Employee leaving the company (0=no, 1=yes)
#DAILY RATE	Numerical Value - Salary Level
#EDUCATION	Numerical Value ?? need to find out
#EMPLOYEE NUMBER	Numerical Value - EMPLOYEE ID
#ENVIROMENT SATISFACTION	Numerical Value - SATISFACTION WITH THE ENVIROMENT
#HOURLY RATE	Numerical Value - HOURLY SALARY
#JOB LEVEL	Numerical Value - LEVEL OF JOB
#MONTHY RATE	Numerical Value - MONTHY RATE how is it different from monthly income? need to find out
#NUMCOMPANIES WORKED	Numerical Value - NO. OF COMPANIES WORKED AT
#OVERTIME	(1=NO, 2=YES) is overtime paid? need to find out maybe? could be paid or unpaid overcome and that impacts the analysis
#PERCENT SALARY HIKE	Numerical Value - PERCENTAGE INCREASE IN SALARY annually or during promotion or compared to industry average?
#RELATIONS SATISFACTION	Numerical Value - RELATIONS SATISFACTION what relations?
#STOCK OPTIONS LEVEL	Numerical Value - STOCK OPTIONS
#TOTAL WORKING YEARS	Numerical Value - TOTAL YEARS WORKED i think this includes other companies
#TRAINING TIMES LAST YEAR	Numerical Value - HOURS SPENT TRAINING
#WORK LIFE BALANCE	Numerical Value - TIME SPENT BEWTWEEN WORK AND OUTSIDE
#YEARS AT COMPANY	Numerical Value - TOTAL NUMBER OF YEARS AT THE COMPNAY
# YEARS IN CURRENT ROLE	Numerical Value -YEARS IN CURRENT ROLE does this include other company?
# YEARS SINCE LAST PROMOTION	Numerical Value - LAST PROMOTION
# YEARS WITH CURRENT MANAGER	Numerical Value - YEARS SPENT WITH CURRENT MANAGER

# =========================== Set WD =========================================================

setwd("/Users/xb/Desktop/Uni Notes/Y2S2/BC2407/project")

set.seed(2025)

data<-fread("WA_Fn-UseC_-HR-Employee-Attrition.csv", stringsAsFactors = TRUE)
dim(data) #1470 rows, 35 columns

data_encoded<-fread("WA_Fn-UseC_-HR-Employee-Attrition.csv", stringsAsFactors = TRUE)


# =========================== Data Cleaning ===================================================

#identified columns stored as char, will converted them to factor
summary(data) 

# Checking for missing values
na_count <- colSums(is.na(data))
print(na_count) # No missing values found

##reason to remove columns:
#reasons to remove column:
sum(data[,Over18!="Y"]) #this column only have 1 value since it is 0, proved it only has Y
length(unique(data[,data$EmployeeCount])) #only 1 unique value
length(unique(data[,data$StandardHours])) #only 1 unique value

# Removing unnecessary columns
cols_to_remove <- c("Over18", "EmployeeCount", "StandardHours")
data <- data[, !cols_to_remove, with=FALSE]

# Convert character columns to factor
char_cols <- names(data)[sapply(data, is.character)]
data[, (char_cols) := lapply(.SD, as.factor), .SDcols = char_cols]
summary(data)

# =========================== for Encoded Data ===================================================

cols_to_remove <- c("Over18", "EmployeeCount", "StandardHours")
data_encoded <- data_encoded[, !cols_to_remove, with = FALSE]

# Binary encoding for Yes/No or Male/Female
data_encoded[, Attrition := ifelse(Attrition == "Yes", 1, 0)]
data_encoded[, Gender := ifelse(Gender == "Male", 1, 0)]
data_encoded[, OverTime := ifelse(OverTime == "Yes", 1, 0)]

# One-hot encode selected categorical columns
data_encoded <- one_hot(as.data.table(data_encoded),
                        cols = c("BusinessTravel", "Department", "EducationField", 
                                 "JobRole", "MaritalStatus"),
                        sparsifyNAs = FALSE)

drop_dummies <- c(
  "Department_Research & Development",         # base for Department
  "EducationField_Life Sciences",              # base for EducationField
  "JobRole_Sales Executive",                   # base for JobRole
  "MaritalStatus_Married",                     # base for Marital Status
  "BusinessTravel_Travel_Rarely"               # base for BusinessTravel
)
data_encoded <- data_encoded[, !drop_dummies, with = FALSE]

# Convert any logical columns to numeric
logical_cols <- names(data_encoded)[sapply(data_encoded, is.logical)]
data_encoded[, (logical_cols) := lapply(.SD, as.integer), .SDcols = logical_cols]


# ========================== EDA ===============================================================

#identify all categorical and numeric data
categorical_vars <- names(data)[sapply(data, function(col) is.character(col) || is.factor(col))]
continuous_vars <- names(data)[sapply(data, is.numeric)]
# Split the data into categorical and continuous
cat_data <- data[, ..categorical_vars]
num_data <- data[, ..continuous_vars]

# Print the names of the variables
cat("Categorical Variables:\n", categorical_vars, "\n\n")
cat("Continuous Variables:\n", continuous_vars, "\n\n")

dim(cat_data) #8 columns of categorical variable
dim(num_data) #24 columns of numerical variable

##observation:
#can see that there is a lot more continuous variable involved.many things in work places are quantified?


# Display the first few rows of each dataset

head(cat_data) 
## attrition is a cat data that we want to predict


head(num_data) 
## numerical data has some columns which are ordinal data rather than continuous.


#get dimensions to do plotting
cat.dim<- c(ceiling(sqrt(ncol(cat_data))), ceiling(ncol(cat_data)/ceiling(sqrt(ncol(cat_data)))))
#get dimensions to do plotting
num.dim<- c(ceiling(sqrt(ncol(num_data))),ceiling(ncol(num_data)/ceiling(sqrt(ncol(num_data)))))

#plot all categorical variables
par(mfrow=cat.dim)

for (i in 1:ncol(cat_data)) {
  barplot(table(cat_data[[i]]), main = colnames(cat_data)[i], xlab = colnames(cat_data)[i], ylab = "Frequency")
}
#from the bar plot, can see that over18 only has Y, proven and will be removed.



#plot all numerical variables
par(mfrow=c(3,3)) #used 3x3 such that graphs can be bigger

for(i in 1:ncol(num_data)){
  boxplot(num_data[[i]], main= colnames(num_data)[i])
} 
#press side panel previous(under plot) to view all graphs

unique(data[,data$PerformanceRating])
#Performance rating is only 3 or 4, not a robust rating system

#plotting response against numerical var
for (i in 1:ncol(num_data)) {
  p <- ggplot(data, aes(x = Attrition, y = num_data[[i]])) +
    geom_violin(fill = "skyblue", trim = FALSE) +
    geom_boxplot(width = 0.1, fill = "white") +
    ggtitle(colnames(num_data)[i]) +
    ylab(colnames(num_data)[i]) +
    xlab("Attrition")
  print(p)
}
#press side panel previous(under plot) to view all graphs
## yes for attrition has lower age(median)
## will be added later


#plotting response against categorical var
for (i in 1:ncol(cat_data)) {
  var_name <- colnames(cat_data)[i]
  
  if (var_name != "Attrition") {  # Skip response itself
    p <- ggplot(data, aes_string(x = var_name, fill = "Attrition")) +
      geom_bar(position = "fill") +
      ylab("Proportion") +
      ggtitle(paste(var_name, "vs Attrition")) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    print(p)
  }
}
#press side panel previous(under plot) to view all graphs
##observations:
## 1. people who has biz travel more has higher attrition rate
## 2. R&D department has lower attrition, HR and sales has higher
## 3. HR education field, technical degree, marketing has high attrition 
## 4. gender no diff on attrition
## 5. for job role, sales rep highest, followed by HR and lab tech
## 6. single higher attrition than married , lowest is divorced. single may have lesser cost than married hence higher attrition, divorced why?
## 7. OT yes has higher attrition


##POSSIBLY IMPORTANT FOR ANALYSIS !!!!!!!!!!!!!!!!!!!!!!
##I find hourly, daily, and monthly rate to be poor variables for this analysis. Here's why:
#If this data relates to US employees, HR law requires hourly employees working over 40 hours in a week to be paid an overtime rate. While salary employees are paid a consistent amount regardless of the number of hours worked.
#Based on the distributions of these columns it seems hourly rates were 'calculated' for salary employees. However, this calculations is useless without the number of hours the employee is actually working.
#The rate columns provide a false representation and could therefore misrepresent it's relationship with variables such as job satisfaction.

# ========================== Feature Selection ==========================================

# Logistic Regression
lg_full <- glm(Attrition ~ ., data = data_encoded, family = "binomial")

# Check the summary of the model
summary(lg_full)

# Check for multicollinearity > 10
vif(lg_full)

# Perform backward stepwise selection based on AIC
lg_step <- step(lg_full, direction = "backward")

# Extract and sort absolute values of coefficients
coef_abs <- abs(coef(lg_step))
sorted_vars <- sort(coef_abs, decreasing = TRUE)
top_vars <- names(sorted_vars)

# Print top 20 features (excluding intercept)
top_vars[top_vars != "(Intercept)"][1:20]

# ======================== Selected Features Dataset==============================================

selected_variables <- c("JobRole", "OverTime", "BusinessTravel", "EducationField", "MaritalStatus", 
                      "JobInvolvement", "EnvironmentSatisfaction", "JobSatisfaction", "Gender",
                      "WorkLifeBalance", "StockOptionLevel", "RelationshipSatisfaction", "TrainingTimesLastYear", 
                      "NumCompaniesWorked")

data_selected <- data[, c("Attrition", selected_variables), with = FALSE]
str(data_selected)


# ======================= Rose Sampling ==========================================================
set.seed(2025)

#Train Test Set
split <- sample.split(data_selected$Attrition, SplitRatio = 0.7)
train <- data_selected[split == TRUE]
test <- data_selected[split == FALSE]

train_rose <- ROSE(Attrition ~ ., data = train, seed = 2025)$data

# Create tables
before <- table(train$Attrition)

after<- table(train_rose$Attrition)

# Print with aligned formatting
cat("Before ROSE:\n")
cat(sprintf("No  : %d\n", before[["No"]]))
cat(sprintf("Yes : %d\n\n", before[["Yes"]]))

cat("After ROSE:\n")
cat(sprintf("No  : %d\n", after[["No"]]))
cat(sprintf("Yes : %d\n", after[["Yes"]]))

summary(train_rose)
#================================================== CART=================================================
set.seed(2025)
# 1. GROW full tree with cp = 0
cart1 <- rpart(Attrition ~ ., data = train_rose,
               method = "class",
               control = rpart.control(minsplit = 20, cp = 0))

# 2. View and plot cross-validation error
printcp(cart1)
par(mfrow=c(1,1))
plotcp(cart1, main = "Cross-validated error vs. Complexity Parameter")

# 3. Find optimal cp using 1-SE rule and prune
CVerror.cap <- cart1$cptable[which.min(cart1$cptable[,"xerror"]), "xerror"] + cart1$cptable[which.min(cart1$cptable[,"xerror"]), "xstd"]
i <- 1; j<- 4
while (cart1$cptable[i,j] > CVerror.cap) {
  i <- i + 1
}

cp.opt = ifelse(i > 1, sqrt(cart1$cptable[i,1] * cart1$cptable[i-1,1]), 1)
cp.opt
cart2 <- prune(cart1, cp = cp.opt)
par(mfrow=c(1,1))
printcp(cart2, digits = 3)
rpart.plot(cart2, nn = T, main = "Optimal Tree")
summary(cart2)


# 4. Variable importance
importance <- cart2$variable.importance
importance_percentage <- (importance / sum(importance)) * 100
importance_df <- data.frame(Variable = names(importance_percentage),
                            Importance = round(importance_percentage, 2))

importance_df <- importance_df[order(-importance_df$Importance), ]
rownames(importance_df) <- NULL
print(importance_df)

# 7. Predict on train set
train_pred_cart <- predict(cart2, newdata = train_rose, type = "class")


# 7. Predict on test set
cart.predictions <- predict(cart2, newdata = test, type = "class")
cart.probs <- predict(cart2, newdata = test, type = "prob")

# 8. Evaluate: Confusion matrix
confusionMatrix(train_pred_cart, train_rose$Attrition) #trainset
confusionMatrix(cart.predictions, test$Attrition) #testset

# 9. ROC and AUC
roc_cart <- roc(response = test$Attrition, predictor = cart.probs[, "Yes"])
auc_cart <- auc(roc_cart)
cat("AUC:", round(auc_cart, 4), "\n")
plot(roc_cart, col = "darkgreen", main = "ROC Curve - Pruned CART")
#================================================== RandomForest==========================================
set.seed(2025)
p <- ncol(train_rose) - 1  # number of predictors (excluding target)

# To store results
results <- data.table(mtry = integer(), ntree = integer(), oob_error = numeric())

# To store best model
best_error <- Inf
best_rf <- NULL
best_params <- c()

# Grid search over mtry and ntree
for (i in 1:p) {
  for (j in seq(50, 800, 50)) {
    
    start_time <- Sys.time()
    
    RF2 <- randomForest(Attrition ~ ., data = train_rose,
                        importance = TRUE, ntree = j, mtry = i)
    
    current_error <- RF2$err.rate[RF2$ntree, "OOB"]
    
    # Store current result
    results <- rbind(results, data.table(mtry = i, ntree = j, oob_error = current_error))
    
    # Update best model if current is better
    if (current_error < best_error) {
      best_error <- current_error
      best_rf <- RF2
      best_params <- c(mtry = i, ntree = j)
    }
    
    end_time <- Sys.time()
    print(paste0("Tested mtry = ", i, ", ntree = ", j, 
                 " | OOB Error = ", round(current_error, 4), 
                 " | Time: ", round(difftime(end_time, start_time, units = "secs"), 2), "s"))
  }
}

# Final output
print(results)
print(paste("Best params - mtry:", best_params["mtry"], "ntree:", best_params["ntree"]))
#mtry = 3 ntree = 550 is best
#fwrite(results, "rf_grid_search_results.csv") #dont rerun this line, will overwrite previous result

RF_best <- RF2 <- randomForest(Attrition ~ ., data = train_rose,
                               importance = TRUE, ntree = 550, mtry = 3)
print(RF_best)

predicted <- predict(RF_best, newdata = test)
confusionMatrix(predicted, test$Attrition)

# Get probabilities of "Yes" class
probs <- predict(RF_best, newdata = test, type = "prob")

# Compute ROC and AUC
roc_obj <- roc(response = test$Attrition, predictor = probs[, "Yes"])
auc(roc_obj)  # Print AUC
plot(roc_obj, col = "blue", main = "ROC Curve")

# =================== CART Performance Comparison ====================

# Confusion Matrix for TRAINING set
cart_train_conf <- confusionMatrix(train_pred_cart, train_rose$Attrition)
cat("\nConfusion Matrix - TRAINING SET (CART):\n")
print(cart_train_conf)

# Confusion Matrix for TEST set
cart_test_conf <- confusionMatrix(cart.predictions, test$Attrition)
cat("\nConfusion Matrix - TEST SET (CART):\n")
print(cart_test_conf)

# =================== Compare Accuracy, Sensitivity, Specificity ====================

cat("\nAccuracy:\n")
cat("  Training:", round(cart_train_conf$overall["Accuracy"], 4), "\n")
cat("  Test    :", round(cart_test_conf$overall["Accuracy"], 4), "\n\n")

cat("Sensitivity (Recall of Yes):\n")
cat("  Training:", round(cart_train_conf$byClass["Sensitivity"], 4), "\n")
cat("  Test    :", round(cart_test_conf$byClass["Sensitivity"], 4), "\n\n")

cat("Specificity (Recall of No):\n")
cat("  Training:", round(cart_train_conf$byClass["Specificity"], 4), "\n")
cat("  Test    :", round(cart_test_conf$byClass["Specificity"], 4), "\n")


# ==================== Evaluate Random Forest Performance ==========================

# Predictions on training set (after ROSE sampling)
train_pred <- predict(RF_best, newdata = train_rose)
train_conf <- confusionMatrix(train_pred, train_rose$Attrition)

cat("Confusion Matrix - TRAINING SET:\n")
print(train_conf)

# Predictions on test set
test_pred <- predict(RF_best, newdata = test)
test_conf <- confusionMatrix(test_pred, test$Attrition)

cat("\nConfusion Matrix - TEST SET:\n")
print(test_conf)

# ==================== Metrics: Recall, Precision, 1 Score, UC-ROC, Balanced Accuracy==========================

get_top5_metrics <- function(actual_labels, pred_class, pred_probs_yes) {
  cm <- table(actual_labels, pred_class)
  
  TP <- cm["Yes", "Yes"]
  TN <- cm["No", "No"]
  FP <- cm["No", "Yes"]
  FN <- cm["Yes", "No"]
  
  precision <- ifelse((TP + FP) == 0, NA, TP / (TP + FP))
  recall <- ifelse((TP + FN) == 0, NA, TP / (TP + FN))
  f1 <- ifelse((precision + recall) == 0, NA, 2 * (precision * recall) / (precision + recall))
  specificity <- ifelse((TN + FP) == 0, NA, TN / (TN + FP))
  balanced_acc <- (recall + specificity) / 2
  
  roc_obj <- roc(actual_labels, pred_probs_yes)
  auc_val <- auc(roc_obj)
  
  return(list(
    Recall = round(recall, 4),
    Precision = round(precision, 4),
    F1_Score = round(f1, 4),
    AUC = round(auc_val, 4),
    Balanced_Accuracy = round(balanced_acc, 4)
  ))
}


# predicted (from RF): class predictions
# probs: probabilities from RF
rf_metrics_test <- get_top5_metrics(test$Attrition, predicted, probs[, "Yes"])


# cart.predictions: class predictions
# cart.probs: probabilities from CART
cart_metrics_test <- get_top5_metrics(test$Attrition, cart.predictions, cart.probs[, "Yes"])


performance_table <- data.frame(
  Model = c("Random Forest", "CART"),
  Recall = c(rf_metrics_test$Recall, cart_metrics_test$Recall),
  Precision = c(rf_metrics_test$Precision, cart_metrics_test$Precision),
  F1_Score = c(rf_metrics_test$F1_Score, cart_metrics_test$F1_Score),
  AUC = c(rf_metrics_test$AUC, cart_metrics_test$AUC),
  Balanced_Accuracy = c(rf_metrics_test$Balanced_Accuracy, cart_metrics_test$Balanced_Accuracy)
)

kable(performance_table, format = "markdown",
      col.names = c("Model", "Recall", "Precision", "F1 Score", "AUC", "Balanced Accuracy"))

