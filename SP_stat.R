# =========================================================================
# Chatroom Task Analysis: P3 Sensitivity & Clinical Outcomes
# R 4.5.1 — Linear Models and Negative Binomial GLMs
# =========================================================================

# 1. Setup and Libraries --------------------------------------------------
suppressPackageStartupMessages({
  library(MASS)      # For glm.nb
  library(broom)     # For tidying model outputs
  library(dplyr)     # For data manipulation
  library(tidyr)     # For data cleaning
  library(car)       # For Type-III Anova and VIF
  library(emmeans)   # For Tukey post-hocs and simple slopes
  library(performance) # For model diagnostics (check_model)
})

# Helper functions for scaling/centering
z <- function(x) as.numeric(scale(x, center = TRUE, scale = TRUE))
mc <- function(x) as.numeric(scale(x, center = TRUE, scale = FALSE))

# 2. Data Preparation -----------------------------------------------------
# Assuming 'raw_data' contains your final sample of N=179
df <- raw_data %>%
  mutate(
    # Factorize Group (Reference: HC)
    group = factor(group, levels = c("HC", "remMDD", "currentMDD")),
    sex   = factor(sex),
    site  = factor(site),
    
    # Standardize primary predictors
    z_delta_p3   = z(delta_p3),             # Rejection - Acceptance at Pz
    z_friend_txt = z(friendship_text_prop), # Friendship-focused communication
    
    # Mean-center continuous covariates
    c_age   = mc(age),
    c_cdrs0 = mc(cdrs_baseline)             # Baseline depressive severity
  )

# 3. Baseline Group Differences in ΔP3 -----------------------------------
# General Linear Model
m_baseline <- lm(delta_p3 ~ group + c_age + sex + site, data = df)

# Omnibus Test (Type-III)
anova_baseline <- Anova(m_baseline, type = "III")
print(anova_baseline)

# Tukey-corrected pairwise comparisons
posthoc_p3 <- emmeans(m_baseline, specs = pairwise ~ group, adjust = "tukey")
summary(posthoc_p3$contrasts)

# 4. Prediction of Depressive Symptoms (12-month CDRS-R) ------------------
# Negative Binomial GLM with Group x ΔP3 interaction
m_cdrs_pred <- glm.nb(cdrs_12m ~ group * z_delta_p3 + c_age + sex + site + c_cdrs0, 
                      data = df)

# Check Collinearity (GVIF)
vif_vals <- vif(m_cdrs_pred)
print(vif_vals)

# Simple Slopes: Association between ΔP3 and symptoms within each group
slopes_cdrs <- emtrends(m_cdrs_pred, ~ group, var = "z_delta_p3")
summary(slopes_cdrs, infer = TRUE)

# 5. Daily Mood Analysis -------------------------------------------------
# Primary model
m_mood1 <- lm(daily_mood_avg ~ z_delta_p3 + c_age + sex + site + group, data = df)

# Secondary model (controlling for baseline severity)
m_mood2 <- lm(daily_mood_avg ~ z_delta_p3 + c_age + sex + site + group + c_cdrs0, 
              data = df)

summary(m_mood2)

# 6. Moderation by Smartphone Communication (3-way Interaction) ----------
# Negative Binomial GLM with log link
m_moderation <- glm.nb(cdrs_12m ~ group * z_delta_p3 * z_friend_txt + 
                       c_age + sex + site + c_cdrs0, data = df)

# Omnibus tests for the 3-way interaction
Anova(m_moderation, type = "III")

# Interpret interactions via Incidence Rate Ratios (IRRs)
tidy_moderation <- tidy(m_moderation, exponentiate = TRUE, conf.int = TRUE)

# Simple Slopes for 3-way interaction: ΔP3 association at ±1 SD of texting
# Estimates association within each diagnostic group
slopes_mod <- emtrends(m_moderation, ~ group | z_friend_txt, 
                       at = list(z_friend_txt = c(-1, 0, 1)), 
                       var = "z_delta_p3")
summary(slopes_mod, infer = TRUE)

# 7. Model Diagnostics ----------------------------------------------------
# Inspect residuals, leverage, and Cook's distance
par(mfrow = c(2, 2))
plot(m_cdrs_pred) 

# Sensitivity check: Overdispersion ratio
od_ratio <- sum(residuals(m_moderation, type = "pearson")^2) / m_moderation$df.residual
cat("Overdispersion Ratio:", od_ratio, "\n")