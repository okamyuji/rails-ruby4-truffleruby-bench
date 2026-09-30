.PHONY: build bench smoke aggregate image-sizes test

DC := docker compose

build:
	$(DC) build mri truffleruby

# 既定は5回。回数や時間は RUNS=3 WARMUP_SEC=60 のように上書きできる。
bench:
	./bin/run_all
	$(MAKE) image-sizes aggregate

# 数分で終わる動作確認。数値は計測に使わない。
smoke:
	RUNS=1 WARMUP_SEC=2 MEASURE_SEC=2 BOOT_SAMPLES=1 THREADS=1,2 OUT=tmp/smoke ./bin/run_all

aggregate:
	$(DC) run --rm -T mri ruby bin/aggregate results/raw results/summary.json

image-sizes:
	./bin/image_sizes results/image_sizes.json

test:
	$(DC) run --rm -T mri ruby test/summary_test.rb
