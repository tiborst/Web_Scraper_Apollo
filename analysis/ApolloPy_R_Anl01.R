## ----setup, include=FALSE------------------------------------------------------------------------------------------------------------------------------------------------------------------
knitr::opts_chunk$set(dpi=300,fig.width=7)


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# clear workspace
rm(list = ls())

library(tidyverse)
library(ggpubr)
suppressPackageStartupMessages(library(rstatix))


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# load data relating to Baleroc 25 hc for each class and spec
files <- list.files("./data_csv/", pattern = "Baleroc_25hc*")

# load data
data           <- lapply(paste0("./data_csv/", files), read.csv)
data_dps       <- lapply(data, function(x) {x$dps})
data_ilvl      <- lapply(data, function(x) {x$avg_item_lvl})
data_fightlen  <- lapply(data, function(x) {x$length})
data_guild     <- lapply(data, function(x) {x$guild})

# get class + spec from filename
class_spec   <- lapply(files, function(x) {strsplit(x, "_")[[1]][3:4]})
class        <- lapply(class_spec, function(x) {x[1]})
spec         <- lapply(class_spec, function(x) {sub(" ", "_", x[2])})
class_spec_2 <- mapply(function(x,y) paste0(x, ".", y), x=class, y=spec)

data_guild <- ifelse(unlist(data_guild)=="", "No Guild", unlist(data_guild))


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# append NAs to each vector if shorter than max_len
max_len <- max(unlist(lapply(data_dps, function(x) {length(x)})))
data_dps_na <- list()
for (i in seq_along(data_dps)) {
 if (length(data_dps[[i]])<max_len) {
   data_dps_na[[i]] <- c(data_dps[[i]], rep(NA_character_, max_len-length(data_dps[[i]])))
 } else {
   data_dps_na[[i]] <- data_dps[[i]]
 }
}
df_wide <- data.frame(x = rep(NA_character_, max_len))

# append columns
for (i in seq_along(data_dps_na)) {
 df_wide[, i] <- data_dps_na[[i]]
}

colnames(df_wide) <- class_spec_2
df <- df_wide %>% 
  gather(key="class_spec", value="DPS") %>% 
  na.omit() %>% 
  mutate()


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# formatting DF
df$DPS       <- as.numeric(df$DPS)
df$ID        <- 1:length(unlist(data_dps))
df$itemlvl   <- as.numeric(unlist(data_ilvl))
df$fight_len <- as.numeric(unlist(data_fightlen))
df$guild     <- data_guild

df$class_spec <- factor(df$class_spec)
df$ID         <- factor(df$ID)
df$guild      <- factor(df$guild)


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# remove non-dps specs
non_dps <- c("Dk.Blood", "Dru.Restoration", "Pal.Holy", "Pal.Protection", "Pri.Discipline", "Pri.Holy", "Sham.Restoration")
df_dps <- df %>% dplyr::filter(!(class_spec %in% non_dps))


## ----echo=FALSE, results='asis'------------------------------------------------------------------------------------------------------------------------------------------------------------
suppressPackageStartupMessages(library(knitr))

# summary statistics
summary_stats <- df %>%
  group_by(class_spec) %>%
  get_summary_stats(DPS, type="mean_sd")

kable(summary_stats)


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# identifying highest DPS spec for each class
classes_unique <- unique(unlist(class))
max_dps_ind <- list()

for (c in classes_unique) {
  
  max_dps_spec <- df$class_spec[df$DPS==max(df$DPS[grep(pattern=paste0(c, ".*"), df$class_spec)])]
  max_dps_ind <- append(max_dps_ind, max_dps_spec)
  
}


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
df_max_dps <- df[df$class_spec %in% as.character(max_dps_ind),]


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
class_colors <- c("#C41E3A", "#FF7C0A", "#AAD372", "#3FC7EB", "#F48CBA", "#FFFFFF", "#FFF468", "#0070DD", "#C69B6D", "#8788EE")
new_x_axis <- c(paste0("n=", length(df_max_dps[df_max_dps$class_spec=="Dk.Unholy",]$class_spec)),
                paste0("n=", length(df_max_dps[df_max_dps$class_spec=="Dru.Balance",]$class_spec)),
                paste0("n=", length(df_max_dps[df_max_dps$class_spec=="Hunt.Survival",]$class_spec)),
                paste0("n=", length(df_max_dps[df_max_dps$class_spec=="Mag.Fire",]$class_spec)),
                paste0("n=", length(df_max_dps[df_max_dps$class_spec=="Pal.Retribution",]$class_spec)),
                paste0("n=", length(df_max_dps[df_max_dps$class_spec=="Pri.Shadow",]$class_spec)),
                paste0("n=", length(df_max_dps[df_max_dps$class_spec=="Rog.Combat",]$class_spec)),
                paste0("n=", length(df_max_dps[df_max_dps$class_spec=="Sham.Elemental",]$class_spec)),
                paste0("n=", length(df_max_dps[df_max_dps$class_spec=="War.Arms",]$class_spec)),
                paste0("n=", length(df_max_dps[df_max_dps$class_spec=="Warl.Demonology",]$class_spec))
)
                      
df_max_dps %>% 
  ggplot( aes(x=class_spec, y=DPS, fill=class_spec)) +
  stat_boxplot(geom="errorbar", width=0.2) +
  geom_boxplot() +
  geom_jitter(color="black", size=0.4, alpha=0.4) +
  scale_fill_manual(values=class_colors) +
  ggtitle("All Classes \n(highest DPS specs)") +
  xlab("Classes") +
  scale_x_discrete(labels=new_x_axis) +
  theme_minimal()


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# QQ Plots
ggqqplot(df_max_dps, "DPS", facet.by="class_spec", size=0.3, color="black")


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
model <- lm(DPS ~ class_spec, data=df_max_dps)
shapiro.test(residuals(model))


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
plot(model, 1)


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
df_max_dps %>% levene_test(DPS ~ class_spec)


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ANOVA results
res.aov <- anova_test(data=df_max_dps, dv=DPS, between=class_spec)
get_anova_table(res.aov)


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ANOVA using Welch's statistic with sig. Levene's Test
res.aov.welch <- welch_anova_test(data=df_max_dps, formula=DPS ~ class_spec)
get_anova_table(res.aov.welch)


## ----echo=FALSE, results='asis'------------------------------------------------------------------------------------------------------------------------------------------------------------
# post hoc comparisons Bonferroni corrected
post_hoc <- df_max_dps %>% 
  pairwise_t_test(
    DPS ~ class_spec,
    paired=FALSE,
    p.adjust.method="bonferroni"
  )
kable(post_hoc)


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
library(ggsignif)

# create list of vectors containing all sig. comparisons
group1      <- post_hoc$group1[post_hoc$p.adj<.05]
group2      <- post_hoc$group2[post_hoc$p.adj<.05]
comparison_list <- unname(mapply(function(x,y) {c(x,y)}, x=group1, y=group2, SIMPLIFY = FALSE))

pval        <- post_hoc$p.adj[post_hoc$p.adj<.05]
pval_star   <- post_hoc$p.adj.signif[post_hoc$p.adj<.05]
annot_empty <- rep("",15)

# set y positions
y_vec <- seq(33000, 55000, (55000-33000)/15)

df_max_dps %>%
  ggplot( aes(x=class_spec, y=DPS, fill=class_spec)) +
  ylim(15000,55000) +
  stat_boxplot(geom="errorbar", width=0.2) +
  geom_boxplot(outlier.alpha=0) +
  geom_signif(
    comparisons=comparison_list,
    annotations=pval_star,
    vjust=0.8,
    y_position=y_vec,
    size=0.3,
    tip_length=0.01
  ) +
  scale_fill_manual(values=class_colors) +
  ggtitle("All Classes sig. differences Bonf. corr. \n(highest DPS specs)") +
  xlab("Classes") +
  scale_x_discrete(labels=new_x_axis) +
  theme_minimal()


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# reorder guild factor levels
df_dps$guild <- factor(df_dps$guild, levels=c("No Guild", "Below Average", "GG", "Illusion", 
                                                      "Prime", "Spice", "Wheelchair Raiders"))


## ----echo=FALSE, results='asis'------------------------------------------------------------------------------------------------------------------------------------------------------------
# summary statistics
sum_stats_guild <- df_dps %>%
  group_by(guild) %>%
  get_summary_stats(DPS, type="mean_sd")
kable(sum_stats_guild)


## ----echo=FALSE, results='asis'------------------------------------------------------------------------------------------------------------------------------------------------------------
summary_stats_guild <- df_dps %>%
  group_by(guild) %>%
  get_summary_stats(itemlvl, type="mean_sd")

kable(summary_stats_guild)


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
colPalette <- c("#994C00", "#E69F00", "#56B4E9", "#009E73", "#0072B2", "#D55E00", "#CC79A7")

g_names <- sum_stats_guild$guild
g_nval <- sum_stats_guild$n
                      
df_dps %>% 
  ggplot( aes(x=guild, y=DPS, fill=guild)) +
  stat_boxplot(geom="errorbar", width=0.2) +
  geom_boxplot() +
  scale_fill_manual(values=colPalette) +
  geom_jitter(color="black", size=0.4, alpha=0.4) +
  ggtitle("Comparing DPS based on guild membership \n(all DPS specs)") +
  xlab("Guilds") +
  scale_x_discrete(labels=unlist(lapply(g_nval, function(x) {paste0("n=",x)}))) +
  labs(fill="Guilds") +
  theme_classic()


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# checking homogeneity of regression slopes 
anova(aov(formula=DPS ~ guild * itemlvl, data=df_dps))


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# comparing model fit for ancova and multiple regression models
ancova   <- lm(DPS ~ guild + itemlvl, data=df_dps)
mult_reg <- lm(DPS ~ guild * itemlvl, data=df_dps)
anova(ancova, mult_reg) 


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# results
anova(mult_reg)


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# create residual vs. fitted plot
suppressPackageStartupMessages(library(lmtest))

plot(fitted(mult_reg), resid(mult_reg), xlab="Fitted Values", ylab="Residuals")
abline(0,0)

# perform Breusch-Pagan test to check for Homoscedasticity
# tests null hypothesis that residuals are distributed with equal variances
bptest(mult_reg)


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# QQ Plots (checking normality of distribution for each factor level)
ggqqplot(df_dps, "DPS", facet.by="guild", size=0.3)


## ----echo=FALSE, results='asis'------------------------------------------------------------------------------------------------------------------------------------------------------------
# post hoc comparisons
post_hoc_guild <- df_dps %>% pairwise_t_test(DPS ~ guild, p.adjust.method = "bonferroni")
kable(post_hoc_guild)


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# boxplots with sig. differences

# list of vectors containing all sig. comparisons
group1_guild          <- post_hoc_guild$group1[post_hoc_guild$p.adj<.05]
group2_guild          <- post_hoc_guild$group2[post_hoc_guild$p.adj<.05]
comparison_list_guild <- unname(mapply(function(x,y) {c(x,y)}, x=group1_guild, y=group2_guild, SIMPLIFY = FALSE))

pval_guild        <- post_hoc_guild$p.adj[post_hoc_guild$p.adj<.05]
pval_star_guild   <- post_hoc_guild$p.adj.signif[post_hoc_guild$p.adj<.05]

df_dps %>%
  ggplot( aes(x=guild, y=DPS, fill=guild)) +
  stat_boxplot(geom="errorbar", width=0.2) +
  geom_boxplot(outlier.alpha=0) +
  scale_fill_manual(values=colPalette) +
  geom_signif(
    comparisons=comparison_list_guild,
    annotations=pval_star_guild,
    vjust=0.7,
    y_position=c(35000, 36500, 38000),
    size=0.6,
    tip_length=0.02
  ) +
  ggtitle("Comparing DPS based on guild membership \n(all DPS specs)") +
  xlab("Guilds") +
  scale_x_discrete(labels=unlist(lapply(g_nval, function(x) {paste0("n=",x)}))) +
  labs(fill="Guilds") +
  theme_classic()


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# plotting itemlvl differences for comparisons

df_dps %>%
  ggplot( aes(x=guild, y=itemlvl, fill=guild)) +
  stat_boxplot(geom="errorbar", width=0.2) +
  geom_boxplot() +
  scale_fill_manual(values=colPalette) +
  geom_jitter(color="black", size=0.4, alpha=0.4) +
  ggtitle("Comparing average item level based on guild membership \n(all DPS specs)") +
  xlab("Guilds") +
  ylab("Avg. Item lvl") +
  scale_x_discrete(labels=unlist(lapply(g_nval, function(x) {paste0("n=",x)}))) +
  labs(fill="Guilds") +
  theme_classic()


## ----echo=FALSE, results='asis'------------------------------------------------------------------------------------------------------------------------------------------------------------
# post hoc comparisons
post_hoc_guild_ilvl <- df_dps %>% pairwise_t_test(itemlvl ~ guild, p.adjust.method = "bonferroni")
kable(post_hoc_guild_ilvl)


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# boxplots with sig. differences of itemlvl

# create list of vectors containing all sig. comparisons
group1_guild_ilvl          <- post_hoc_guild_ilvl$group1[post_hoc_guild_ilvl$p.adj<.05]
group2_guild_ilvl          <- post_hoc_guild_ilvl$group2[post_hoc_guild_ilvl$p.adj<.05]
comparison_list_guild_ilvl <- unname(mapply(function(x,y) {c(x,y)}, x=group1_guild_ilvl, y=group2_guild_ilvl, SIMPLIFY = FALSE))

pval_star_guild_ilvl   <- post_hoc_guild_ilvl$p.adj.signif[post_hoc_guild_ilvl$p.adj<.05]

df_dps %>%
  ggplot( aes(x=guild, y=itemlvl, fill=guild)) +
  ylim(360,400) +
  stat_boxplot(geom="errorbar", width=0.2) +
  scale_fill_manual(values=colPalette) +
  geom_boxplot(outlier.alpha=0) +
  geom_signif(
    comparisons=comparison_list_guild_ilvl,
    annotations=pval_star_guild_ilvl,
    vjust=0.7,
    y_position=c(394,396,398),
    size=0.6,
    tip_length=0.02
    ) +
  ggtitle("Comparing average item level based on guild membership (Bonferroni corrected) \n(all DPS specs)") +
  xlab("Guilds") +
  ylab("Avg. Item lvl") +
  labs(fill="Guilds") +
  scale_x_discrete(labels=unlist(lapply(g_nval, function(x) {paste0("n=",x)}))) +
  theme_classic()


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
correl <- cor.test(df_dps$DPS,df_dps$itemlvl)
correl


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# scatterplot: relationship between item level and guild membership to DPS

df_dps %>% 
  ggplot() +
  geom_point( aes(x=itemlvl, y=DPS, fill=guild, color=guild), size=1) +
  scale_color_manual(values=colPalette) +
  labs(color="Guilds") +
  geom_smooth( aes(x=itemlvl, y=DPS), method="lm", se=FALSE, color="black", size=0.5) +
  annotate(geom="text", label=paste0("DPS ~ Item Level \n(r=", round(correl$estimate, 2), ")***"), 
           x=366, y=20000, size=3, color="black") +
  ggtitle("Relationship of guild membership and item level to DPS") +
  xlab("Average Item Level") +
  guides(fill=FALSE) +
  theme_classic()


## ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# scatterplot with abline for each guild with its own geom_smooth (should be possible by putting the aesthetics back into ggplot())
# + using facet_wrap()
df_dps %>% 
  ggplot( aes(x=itemlvl, y=DPS, fill=guild, color=guild)) +
  geom_point(size=1) +
  scale_color_manual(values=colPalette) +
  labs(color="Guilds") +
  geom_smooth(method="lm", se=FALSE, size=0.5, color="black") +
  ggtitle("Relationship of guild membership and item level to DPS") +
  xlab("Average Item Level") +
  guides(fill=FALSE) +
  facet_wrap(~guild, nrow=2, as.table=FALSE) +
  theme_classic()


