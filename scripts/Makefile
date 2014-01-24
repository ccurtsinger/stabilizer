
all: ../fig/overhead.pdf ../fig/qq.pdf ../fig/optimizations.pdf

../fig/overhead.pdf: overhead.r ../data/overhead_data.r
	@echo "[R] Building overhead plot"
	@r --quiet --no-save -f overhead.r > /dev/null

../fig/qq.pdf: qq.r ../data/qq_data.csv
	@echo "[R] Building Q-Q plot"
	@r --quiet --no-save -f qq.r > /dev/null

../fig/optimizations.pdf: speedup.r ../data/anova_data.csv
	@echo "[R] Building Optimizations plot"
	@r --quiet --no-save -f speedup.r > /dev/null