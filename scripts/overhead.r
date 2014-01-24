library(ggplot2)
library(grid)

source('../data/overhead_data.r')

# skip GemsFDTD--partial results only
dat <- subset(dat, benchmark!='GemsFDTD')

dat.link <- subset(dat, ext=='link')
dat.link.means <- tapply(dat.link$time, dat.link$benchmark, mean)

overhead <- subset(dat, ext!='link')
overhead$time <- overhead$time / dat.link.means[overhead$benchmark]

overhead$ext <- factor(overhead$ext, levels=c('code', 'code.stack', 'code.heap.stack'))
overhead$benchmark <- factor(overhead$benchmark, levels=c('namd', 'mcf', 'hmmer', 'libquantum', 'bzip2', 'astar', 'milc', 'lbm', 'sphinx3', 'gromacs', 'wrf', 'sjeng', 'h264ref', 'gobmk', 'zeusmp', 'cactusADM', 'gcc', 'perlbench'))

p <- qplot(
	x=benchmark, y=time, data=overhead, 
    stat='summary', fun.y='mean', geom='bar', fill=ext, position='dodge', 
    main=expression(paste('Overhead of S', scriptstyle('TABILIZER'))),
    xlab='',
    ylab=expression(paste('Overhead ', bgroup( '(', frac(plain('time')['<config>'], plain('time')['link']), ')')))
) + scale_fill_grey(start=0.8, end=0.20) + 
	theme_bw(10, 'Times') + 
	theme(
		plot.title = element_text(size=10, face='bold'),
		plot.margin = unit(c(0, 0, 0, 0), 'in'),
		panel.border = element_rect(colour='gray'),
		legend.margin = unit(0, 'in'),
		legend.key = element_rect(color=NA),
		legend.key.size = unit(0.15, 'in'),
		axis.title.y = element_text(size=9),
		axis.text.x = element_text(angle = 50, hjust = 1)
	) +
	scale_y_continuous(breaks=c(0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5))

update_labels(p, list(fill='Randomization'))

ggsave(filename='../fig/overhead.pdf', width=7, height=2)
