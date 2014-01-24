
dat <- read.csv('../data/anova_data.csv')

# Remove the max runs (first run)
dat.max <- tapply(dat$time, interaction(dat$benchmark, dat$tune), max)
dat <- subset(dat, time != dat.max[interaction(benchmark, tune)])

dat.O1.O2 <- subset(dat, tune %in% factor(c(' O1', ' O2'), levels=levels(dat$tune)))
dat.O2.O3 <- subset(dat, tune %in% factor(c(' O2', ' O3'), levels=levels(dat$tune)))

# Run the whole thing first
summary(aov(time ~ tune + Error(benchmark/tune), dat))
# Yes, 'tune' has a significant impact comparing within bencmarks

# Look at just the subset with O1 and O2
summary(aov(time ~ tune + Error(benchmark/tune), dat.O1.O2))
# 'tune' is significant at the 90% level, but not 95%

# Now just O2 and O3
summary(aov(time ~ tune + Error(benchmark/tune), dat.O2.O3))
# 'tune' is not significant (well, it is at the 73.9% level)
