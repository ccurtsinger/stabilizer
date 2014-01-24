library(ggplot2)
library(grid)

dat <- read.csv('../data/anova_data.csv')

dat.O1 <- subset(dat, tune == factor(' O1', levels=levels(dat$tune)))
dat.O2 <- subset(dat, tune == factor(' O2', levels=levels(dat$tune)))
dat.O3 <- subset(dat, tune == factor(' O3', levels=levels(dat$tune)))

means.O1 <- tapply(dat.O1$time, dat.O1$benchmark, mean)
means.O2 <- tapply(dat.O2$time, dat.O2$benchmark, mean)
means.O3 <- tapply(dat.O3$time, dat.O3$benchmark, mean)

benchmarks <- levels(dat$benchmark)
speedup.O2 <- (means.O1[benchmarks] / means.O2[benchmarks])[benchmarks]
speedup.O3 <- (means.O2[benchmarks] / means.O3[benchmarks])[benchmarks]

significant.O2 <- c()
significant.O3 <- c()

alpha <- 0.05

asterisks.O2 <- c()
asterisks.O3 <- c()

for(b in benchmarks) {
    times.O1 <- subset(dat.O1, benchmark == factor(b, levels=benchmarks))$time
    times.O2 <- subset(dat.O2, benchmark == factor(b, levels=benchmarks))$time
    times.O3 <- subset(dat.O3, benchmark == factor(b, levels=benchmarks))$time
    
    if(b %in% c('hmmer', 'wrf', 'zeusmp')) {
        test.O2 <- wilcox.test(times.O1, times.O2)$p.value <= alpha
        test.O3 <- wilcox.test(times.O2, times.O3)$p.value <= alpha
    } else {
        test.O2 <- t.test(times.O1, times.O2)$p.value <= alpha
        test.O3 <- t.test(times.O2, times.O3)$p.value <= alpha
    }
    
    if(test.O2 == TRUE) {
        significant.O2 <- c(significant.O2, 'Yes')
    } else {
        significant.O2 <- c(significant.O2, 'No')
    }
    
    if(test.O3 == TRUE) {
        significant.O3 <- c(significant.O3, 'Yes')
    } else {
        significant.O3 <- c(significant.O3, 'No')
    }

	if(mean(times.O1) < mean(times.O2)) {
		asterisks.O2 <- c(asterisks.O2, '*')
	} else {
		asterisks.O2 <- c(asterisks.O2, '')
	}
	
	if(mean(times.O2) < mean(times.O3)) {
		asterisks.O3 <- c(asterisks.O3, '*')
	} else {
		asterisks.O3 <- c(asterisks.O3, '')
	}
}

speedup <- data.frame(
	benchmark=c(benchmarks, benchmarks),
    significant=c(significant.O2, significant.O3),
	tune=c(rep('O2 vs. O1', length(benchmarks)), rep('O3 vs. O2', length(benchmarks))),
	speedup=c(speedup.O2, speedup.O3),
	slowdown=c(asterisks.O2, asterisks.O3)
)

p <- qplot(benchmark, speedup, data=speedup, 
    fill=significant, 
    position='dodge', geom='bar',
    main='Impact of Optimizations',
    facets=~tune
) + stat_bin(geom='text', aes(label=slowdown)) +
	scale_fill_grey(start=0.8, end=0.20) + 
    theme_bw(10, 'Times') + 
    theme(
        plot.title = element_text(size=10, face='bold'),
        strip.background = element_rect(color='dark gray', linetype=0.5),
        plot.margin = unit(c(0, 0, 0, 0), 'in'),
        panel.border = element_rect(colour='gray'),
        legend.margin = unit(0, 'in'),
		legend.key = element_rect(color=NA),
        legend.key.size = unit(0.15, 'in'),
        axis.title.y = element_text(size=9),
        axis.text.x = element_text(angle = 50, hjust = 1)
    ) +
    scale_y_continuous(breaks=c(0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5))

update_labels(p, list(
    fill='Significant', 
    x='',
    y='Speedup'
))

ggsave(filename='../fig/optimizations.pdf', width=7, height=2)
