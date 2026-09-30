.PHONY: build bench bench-pg bench-rubyopt bench-puma probe smoke aggregate image-sizes test

DC := docker compose

build:
	$(DC) build mri truffleruby

# 既定は3回。回数や温め時間は RUNS=5 TR_WARMUP_SEC=180 のように上書きできる。
bench:
	./bin/run_all
	$(MAKE) image-sizes aggregate

# DBを使う3ワークロードを、別コンテナのPostgreSQLにつないで測る
PG_URL := postgres://bench:bench@postgres/bench
bench-pg:
	$(DC) up -d --wait postgres
	DATABASE_URL=$(PG_URL) WORKLOADS="html_index json_index create" OUT=results/raw-pg ./bin/run_all
	$(DC) run --rm -T mri ruby bin/aggregate results/raw-pg results/summary-pg.json

# YJIT を Rails の既定で有効にした場合と RUBYOPT=--yjit の場合の、起動時間とスループットの比較
bench-rubyopt:
	RUNTIMES="mri-yjit mri-yjit-rubyopt" WORKLOADS=html_index OUT=results/rubyopt ./bin/run_all
	$(DC) run --rm -T mri ruby bin/aggregate results/rubyopt results/summary-rubyopt.json

# Puma を前段に立て、別コンテナの oha から HTTP で負荷をかける参考計測（PostgreSQL の html_index のみ）
bench-puma:
	./bin/bench_puma
	$(DC) run --rm -T mri ruby bin/aggregate_puma
	$(DC) stop postgres

# TruffleRuby で別スレッドへ移したときに速さが落ちる原因の切り分け（約1時間）
probe:
	mkdir -p results/probe
	for n in 1 2; do \
	  $(DC) run --rm -T truffleruby ruby bin/probe_threads html_index results/probe/html_index-$$n.json && \
	  $(DC) run --rm -T truffleruby ruby bin/probe_threads health results/probe/health-$$n.json || exit 1; \
	done
	$(DC) run --rm -T -e TRUFFLERUBYOPT=--engine.TraceCompilation truffleruby \
	  ruby bin/probe_threads html_index results/probe/html_index-trace.json 2> results/probe/html_index-trace.log

# 数分で終わる動作確認。数値は計測に使わない。
smoke:
	RUNS=1 MRI_WARMUP_SEC=2 TR_WARMUP_SEC=2 MRI_PARALLEL_WARMUP_SEC=2 TR_PARALLEL_WARMUP_SEC=2 MEASURE_SEC=2 BOOT_SAMPLES=1 THREADS=1,2 OUT=tmp/smoke ./bin/run_all

aggregate:
	$(DC) run --rm -T mri ruby bin/aggregate results/raw results/summary.json

image-sizes:
	./bin/image_sizes results/image_sizes.json

test:
	$(DC) run --rm -T mri ruby test/summary_test.rb
