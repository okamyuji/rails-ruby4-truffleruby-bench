require "json"

# bin/bench と bin/probe_threads が共有する、データ投入とリクエスト1件の実行。
module Workload
  REQUESTS = {
    "health" => { method: "GET", path: "/up", status: 200 },
    "html_index" => { method: "GET", path: "/articles", status: 200 },
    "json_index" => { method: "GET", path: "/api/articles", status: 200 },
    "create" => { method: "POST", path: "/api/articles", status: 201 }
  }.freeze

  module_function

  def setup_db
    ActiveRecord::Schema.verbose = false
    load Rails.root.join("db/schema.rb").to_s
    rng = Random.new(42)
    now = Time.utc(2026, 9, 1)
    Author.insert_all(Array.new(20) { |i| { name: "Author #{i + 1}", created_at: now, updated_at: now } })
    Article.insert_all(Array.new(1_000) do |i|
      { author_id: rng.rand(1..20), title: "Article #{i + 1}", body: "Lorem ipsum dolor sit amet. " * 12,
        score: rng.rand(0..100), published: true, published_at: now - (i * 3600), created_at: now, updated_at: now }
    end)
    Comment.insert_all(Array.new(5_000) do |i|
      { article_id: rng.rand(1..1_000), body: "Comment #{i + 1} consectetur adipiscing elit.", created_at: now, updated_at: now }
    end)
  end

  def call(workload, seq)
    spec = REQUESTS.fetch(workload)
    opts = { method: spec[:method] }
    if spec[:method] == "POST"
      opts[:input] = JSON.generate(article: { author_id: (seq % 20) + 1, title: "Bench #{seq}",
                                              body: "Bench body text for create workload. " * 4, score: seq % 101 })
      opts["CONTENT_TYPE"] = "application/json"
    end
    status, _headers, body = Rails.application.call(Rack::MockRequest.env_for(spec[:path], opts))
    size = 0
    body.each { size += it.bytesize }
    body.close if body.respond_to?(:close)
    raise "#{workload}: unexpected status #{status}" unless status == spec[:status]
    raise "#{workload}: empty body" if size.zero?
  end

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # sec 秒まわし、1秒ごとの処理件数を並べて返す。seq はリクエストの通し番号の開始値。
  def curve(workload, sec, seq)
    out = []
    deadline = now + sec
    bucket_end = now + 1
    count = 0
    while (t = now) < deadline
      # 1リクエストが1秒をまたいでも区間を欠かさないよう、経過した区間の数だけ詰める
      while t >= bucket_end
        out << count
        count = 0
        bucket_end += 1
      end
      call(workload, seq += 1)
      count += 1
    end
    out
  end
end
