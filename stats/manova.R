library(effectsize)
library(MASS)

csv_file <- read.csv("32_sample.csv")
csv_file[1, ]

independent_investor <- cbind(csv_file$investor_count, csv_file$member_count)
dependent_investor <- cbind(csv_file$net_running_earning, csv_file$average.net.earning, csv_file$m_partners_earning)
manova_inv <- manova(dependent_investor ~ independent_investor, data=csv_file)
summary(manova_inv)
summary.aov(manova_inv)
eta_squared(manova_inv)
lda(independent_investor ~ dependent_investor, CV = F)

independent_environment <- cbind(csv_file$nursery_count)
dependent_environment <- cbind(csv_file$Native, csv_file$Exotic)
manova_env <- manova(dependent_environment~independent_environment, data=csv_file)
summary(manova_env)
summary.aov(manova_env)
eta_squared(manova_env)
lda(independent_environment ~ dependent_environment, CV = F)

independent_social <- cbind(csv_file$police_count, csv_file$member_count)
dependent_social <- cbind(csv_file$m_independent_earning, csv_file$net_running_earning)
manova_social <- manova(dependent_social~independent_social, data=csv_file)
summary(manova_social)
summary.aov(manova_social)
eta_squared(manova_social)
lda(independent_social ~ dependent_social, CV = F)

nursery_ind <- csv_file$nursery_count
police_ind <- csv_file$police_count
member_ind <- csv_file$member_count
inv_ind <- csv_file$investor_count
price_ind <- csv_file$exotic_price_per_bdft
all_dependent <- cbind(csv_file$Native, csv_file$Exotic, csv_file$net_running_earning, csv_file$average.net.earning, csv_file$average_partners_earning, csv_file$average_independent_earning, csv_file$inv_harvested_trees)

manova_nursery <- manova(all_dependent~nursery_ind, data=csv_file)
summary(manova_nursery)
summary.aov(manova_nursery)
eta_squared(manova_nursery)
lda(nursery_ind ~ all_dependent, CV = F)

manova_police <- manova(all_dependent~police_ind, data=csv_file)
summary(manova_police)
summary.aov(manova_police)
eta_squared(manova_police)
lda(police_ind ~ all_dependent, CV = F)

manova_member <- manova(all_dependent~member_ind, data=csv_file)
summary(manova_member)
summary.aov(manova_member)
eta_squared(manova_member)
lda(member_ind ~ all_dependent, CV = F)

manova_inv <- manova(all_dependent~inv_ind, data=csv_file)
summary(manova_inv)
summary.aov(manova_inv)
eta_squared(manova_inv)
lda(member_ind ~ all_dependent, CV = F)

manova_price <- manova(all_dependent~price_ind, data=csv_file)
summary(manova_price)
summary.aov(manova_price)
eta_squared(manova_price)
price_lda <- lda(price_ind~all_dependent, CV = F)
price_lda


lda_df <- data.frame(
  LD2 = csv_file$net_standing,
  lda = predict(price_lda)$x
)
lda_df


ggplot(lda_df) +
  geom_point(aes(x = LD1, y = LD2, color = price_ind), size = 2) +
  theme_classic()