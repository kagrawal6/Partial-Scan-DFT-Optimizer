# Convenience targets (Synopsys steps still need interactive tool sessions).

.PHONY: check metric help

help:
	@echo "make check   - verify required files exist"
	@echo "make metric  - recompute M for data/exploration_results.csv"
	@echo "Use ./run.sh pscan-synth | pscan-atpg | fullscan-synth | fullscan-atpg for CAD flows"

check:
	./run.sh check

metric:
	./run.sh metric
