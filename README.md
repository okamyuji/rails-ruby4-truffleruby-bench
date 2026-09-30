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
make build   # MRI と TruffleRuby のイメージを作る（約1分、ベースイメージの取得を除く）
make smoke   # 約2分の動作確認（数値は tmp/smoke に出て、計測には使わない）
make bench   # SQLiteの本計測。既定は3回で、8 CPUの環境で約1時間56分かかる
```

PostgreSQLにつないだ計測と、TruffleRubyのスレッドの切り分けは、別のターゲットで実行します。

```bash
make bench-pg  # PostgreSQL 18.4のコンテナを起動し、DBを使う3ワークロードを測る（約1時間35分）
make probe     # TruffleRubyで処理を別スレッドへ移したときの落ち込みを測る（約47分）
```

`make bench`は`results/raw/<runtime>/run-<n>/`に生の結果を書き、`results/summary.json`に回ごとの中央値・最小・最大をまとめます。回数と時間は環境変数で変えられます。

```bash
RUNS=1 TR_WARMUP_SEC=120 make bench
```

## ランタイムとYJITの有効化

| サービス | 内容 |
|---|---|
| `mri` | MRI Ruby 4.0.7。`RAILS_YJIT=false`でRailsによるYJITの自動有効化を止めます |
| `mri-yjit` | MRI Ruby 4.0.7。Rails 8.1の既定どおり、起動処理の最後でRailsがYJITを有効にします |
| `mri-yjit-rubyopt` | MRI Ruby 4.0.7。`RUBYOPT=--yjit`で、プロセスの開始時からYJITを有効にします |
| `truffleruby` | TruffleRuby 40.0.0（Ruby 4.0.2互換、Native構成） |

`load_defaults 8.1`は、production環境で`config.yjit`をtrueにします。このため`RUBYOPT`を付けなくてもYJITは有効になります。YJITなしで測るには`config.yjit`をfalseにしてください。各計測結果の`yjit_enabled`には、計測を終えた時点でYJITが有効だったかを記録しています。

`make bench`の既定は`mri`、`mri-yjit`、`truffleruby`の3つです。`mri-yjit-rubyopt`を測るときは`RUNTIMES=mri-yjit-rubyopt ./bin/run_all`を実行してください。

## 何を測るか

アプリは記事（Article）、著者（Author）、コメント（Comment）の3モデルとSQLiteで構成し、起動時に同じ乱数の種で著者20件、記事1,000件、コメント5,000件を投入します。リクエストは`Rack::MockRequest`で組み立てて`Rails.application.call`へ直接渡すため、HTTPサーバーとネットワークは計測に入りません。

| ワークロード | リクエスト | 主に効く処理 |
|---|---|---|
| `health` | `GET /up` | ルーティングとミドルウェアの往復（`Rails::HealthController`） |
| `html_index` | `GET /articles` | ActiveRecordの読み込み（includes）とERBのコレクションパーシャル描画 |
| `json_index` | `GET /api/articles` | ActiveRecordの読み込みと `as_json` によるJSON生成 |
| `create` | `POST /api/articles` | パラメーター解析、バリデーション、INSERT |

1つのワークロードは1つのプロセスで測ります。各プロセスはウォームアップの間の1秒ごとの処理件数を記録し、続く`MEASURE_SEC`秒（既定15秒）で1リクエストごとの所要時間を記録します。ウォームアップはTruffleRubyが`TR_WARMUP_SEC`（既定300秒）、MRIとYJITが`MRI_WARMUP_SEC`（既定30秒）です。試走で定常の95%に届くまで、TruffleRubyは約100秒、MRIとYJITは2秒かかりました。`html_index`と`json_index`では、最大のスレッド数でTruffleRubyは`TR_PARALLEL_WARMUP_SEC`（既定120秒）、MRIとYJITは`MRI_PARALLEL_WARMUP_SEC`（既定10秒）まわしてから、スレッド数1、2、4、8で同じ秒数ずつ処理件数を数えます。TruffleRubyは処理を別スレッドで回し始めると最適化済みのコードを作り直すので、その期間を計測から外すためです。

起動時間は`bin/boot`が、プロセスの起動からRailsが最初のレスポンスを返して終了するまでを親プロセスの側から測ります。

## ファイル

- `app/`と`config/`と`db/schema.rb`は計測対象のRailsアプリです。
- `bin/bench`は1ワークロードを1プロセスで測ります。
- `bin/boot`は起動時間を測ります。
- `bin/run_all`は全ランタイムと全ワークロードを`RUNS`回まわします。
- `bin/aggregate`と`lib/summary.rb`は回ごとの結果を中央値・最小・最大へまとめます。
- `bin/image_sizes`は`docker image inspect`のサイズを記録します。
- `bin/probe_threads`はTruffleRubyのスレッドの切り分けに使います。
- `results/`には記事で使った計測結果を置きます。

## ライセンス

MIT License. Copyright (c) 2026 okamyuji
