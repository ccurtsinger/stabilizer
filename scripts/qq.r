library(ggplot2)
library(grid)
library(HH)

dat <- read.csv('../data/qq_data.csv')

# Remove the max element from each (first run)
dat.max <- tapply(dat$time, interaction(dat$benchmark, dat$ext), max)
dat <- subset(dat, time != dat.max[interaction(benchmark, ext)])

# Compute the mean and standard deviation for each benchmark*configuration
dat.means <- tapply(dat$time, interaction(dat$benchmark, dat$ext), mean)
dat.sd <- tapply(dat$time, interaction(dat$benchmark, dat$ext), sd)

# Shift to a mean of zero and normalize variance to the re-randomized version
dat$time <- dat$time - dat.means[interaction(dat$benchmark, dat$ext)]
dat$time <- dat$time / dat.sd[interaction(dat$benchmark, factor(c('re-randomized', 're-randomized'), levels=levels(dat$ext)))]

# Add a slope column to the dataset (just the standard deviation: slope of the QQ line)
dat <- data.frame(
	benchmark=dat$benchmark,
	ext=dat$ext,
	time=dat$time,
	slope=tapply(dat$time, interaction(dat$benchmark, dat$ext), sd)[interaction(dat$benchmark, dat$ext)]
)

# Build the plot
p <- ggplot(dat, aes(sample=time, asp=1, color=ext)) +
	stat_qq(size=I(1.5)) + 
	geom_abline(aes(color=ext, slope=slope), alpha=I(1/2)) +
	facet_wrap(~benchmark) +
	theme_bw(10, 'Times') + 
	theme(
		plot.title = element_text(size=10, face='bold'),
		plot.margin = unit(c(0, 0.25, 0.25, 0), 'in'),
		panel.border = element_rect(color='dark gray'),
		strip.background = element_rect(color='dark gray', linetype=0.5),
		legend.margin = unit(0, 'in'),
		legend.key = element_rect(linetype=0),
		legend.key.size = unit(0.15, 'in'),
		axis.title.y = element_text(size=9),
		axis.title.x = element_text(size=9),
		legend.position = c(0.8, 0.1)
	) +
	scale_color_grey(start=0.6, end=0.1, breaks=c('re-randomized', 'randomized'), labels=c('Re-randomization', 'One-time Randomization')) +
	scale_shape_discrete(solid=FALSE) +
	opts(aspect.ratio = 1) +
	ggtitle(expression(paste('Distribution of Runtimes with S', scriptstyle('TABILIZER'), '\'s Repeated and One-Time Layout Randomization')))

# WARNING: Britishisms required here
update_labels(p, list(x='Normal Quantile', y='Observed Quantile', colour='Randomization'))

# Save the plot
ggsave(filename='../fig/qq.pdf', width=7.0, height=6.5)

# Run hypothesis tests
norm.rand <- c()
norm.rerand <- c()
variances <- c()

for(b in levels(dat$benchmark)) {
    dat.b <- subset(dat, benchmark==b)
    dat.b.rand <- subset(dat.b, ext=='randomized')
    dat.b.rerand <- subset(dat.b, ext=='re-randomized')

    norm.rand <- c(norm.rand, shapiro.test(dat.b.rand$time)$p.value)
    norm.rerand <- c(norm.rerand, shapiro.test(dat.b.rerand$time)$p.value)
    variances <- c(variances, hov(time~ext, data=dat.b)$p.value)
}

tests <- data.frame(
    benchmark=levels(dat$benchmark),
    norm.rand=norm.rand,
    norm.rerand=norm.rerand,
    variances=variances
)

write.csv(tests, file='tests.csv')
