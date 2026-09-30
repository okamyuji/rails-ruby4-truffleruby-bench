# WEB_CONCURRENCY=0 のときはワーカーを作らず1プロセスで動かす（TruffleRuby はスレッドで複数のCPUを使うため）
workers Integer(ENV.fetch("WEB_CONCURRENCY", "0"))
threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", "3"))
threads threads_count, threads_count
port 3000
preload_app!
