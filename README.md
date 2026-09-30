# rails-ruby4-truffleruby-bench

Rails 8.1.4のアプリをMRI Ruby 4.0.7、MRI Ruby 4.0.7 + YJIT、TruffleRuby 40.0.0（Ruby 4.0.2互換）の3ランタイムで動かし、Railsで時間を使う処理ごとの速さと起動時間とメモリを比べるベンチマークです。すべての計測はDockerコンテナの中で行い、1回ごとに新しいコンテナを起動して複数回まわします。

## 必要なもの

- DockerとDocker Compose v2
- 8 CPU / 12GB程度を割り当てたDocker環境（並列計測で8スレッドまで使います）
- `make`と`bash`

## 再現手順

```bash
git clone https://github.com/okamyuji/rails-ruby4-truffleruby-bench.git
cd rails-ruby4-truffleruby-bench
make build   # MRI と TruffleRuby のイメージを作る
make smoke   # 数分の動作確認（数値は tmp/smoke に出て、計測には使わない）
make bench   # 本計測。既定は5回で、8 CPUの環境で約6時間かかる
```

`make bench`は`results/raw/<runtime>/run-<n>/`に生の結果を書き、`results/summary.json`に回ごとの中央値・最小・最大をまとめます。回数と時間は環境変数で変えられます。

```bash
RUNS=3 WARMUP_SEC=60 MEASURE_SEC=10 make bench
```

## 何を測るか

アプリは記事（Article）、著者（Author）、コメント（Comment）の3モデルとSQLiteで構成し、起動時に同じ乱数の種で著者20件、記事1,000件、コメント5,000件を投入します。リクエストは`Rack::MockRequest`で組み立てて`Rails.application.call`へ直接渡すため、HTTPサーバーとネットワークは計測に入りません。

| ワークロード | リクエスト | 主に効く処理 |
|---|---|---|
| `health` | `GET /up` | ルーティングとミドルウェアの往復（`Rails::HealthController`） |
| `html_index` | `GET /articles` | ActiveRecordの読み込み（includes）とERBのコレクションパーシャル描画 |
| `json_index` | `GET /api/articles` | ActiveRecordの読み込みと `as_json` によるJSON生成 |
| `create` | `POST /api/articles` | パラメーター解析、バリデーション、INSERT |

1つのワークロードは1つのプロセスで測ります。各プロセスは`WARMUP_SEC`秒のウォームアップで1秒ごとの処理件数を記録し、続く`MEASURE_SEC`秒で1リクエストごとの所要時間を記録します。`html_index`と`json_index`では、さらにスレッド数1、2、4、8で同じ秒数ずつ処理件数を数えます。

起動時間は`bin/boot`が、プロセスの起動からRailsが最初のレスポンスを返して終了するまでを親プロセスの側から測ります。

## ファイル

- `app/`と`config/`と`db/schema.rb`は計測対象のRailsアプリです。
- `bin/bench`は1ワークロードを1プロセスで測ります。
- `bin/boot`は起動時間を測ります。
- `bin/run_all`は全ランタイムと全ワークロードを`RUNS`回まわします。
- `bin/aggregate`と`lib/summary.rb`は回ごとの結果を中央値・最小・最大へまとめます。
- `bin/image_sizes`は`docker image inspect`のサイズを記録します。
- `results/`には記事で使った計測結果を置きます。

## ライセンス

MIT License. Copyright (c) 2026 okamyuji
