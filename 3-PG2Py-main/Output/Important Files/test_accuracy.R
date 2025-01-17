data <- read.csv("validation.csv")

# Perform a paired t-test
# expected, predicted
t_test_result <- t.test(data$exp_mean_dbh, data$pred_mean_dbh, paired = TRUE)
print("mean dbh")
print(t_test_result)

t_test_result <- t.test(data$exp_stand_age, data$pred_stand_age, paired = TRUE)
print("stand age")
print(t_test_result)

t_test_result <- t.test(data$exp_stand_basal_area, data$pred_stand_basal_area, paired = TRUE)
print("stand basal area")
print(t_test_result)