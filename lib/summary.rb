require "json"

# results/raw/<runtime>/run-<n>/*.json を読み、回ごとの値の中央値・最小・最大へまとめる。
module Summary
  module_function

  def stats(values)
    sorted = values.sort
    raise ArgumentError, "values is empty" if sorted.empty?

    mid = sorted.size / 2
    median = sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
    { median: median, min: sorted.first, max: sorted.last, n: sorted.size }
  end

  def speedups(parallel)
    base = parallel.find { it["threads"] == 1 }&.fetch("rps")
    raise ArgumentError, "threads=1 is missing" unless base

    parallel.to_h { [it["threads"], it["rps"] / base] }
  end

  def build(raw_dir)
    Dir.children(raw_dir).sort.to_h do |runtime|
      runs = Dir.glob(File.join(raw_dir, runtime, "run-*")).sort
      [runtime, summarize_runtime(runs)]
    end
  end

  def summarize_runtime(runs)
    boot = runs.map { stats(load(File.join(it, "boot.json"))["boot_ms"])[:median] }
    workloads = runs.flat_map { Dir.glob(File.join(it, "*.json")) }
                    .map { File.basename(it, ".json") }.uniq - ["boot"]
    {
      description: load(Dir.glob(File.join(runs.first, "*.json")).find { !it.end_with?("boot.json") })["ruby_description"],
      boot_ms: stats(boot),
      workloads: workloads.sort.to_h { |w| [w, summarize_workload(runs.map { load(File.join(it, "#{w}.json")) })] }
    }
  end

  def summarize_workload(results)
    out = %w[rps p50_ms p99_ms peak_rss_mb].to_h { |k| [k, stats(results.map { it[k] })] }
    curve_len = results.map { it["warmup_rps"].size }.min
    out["warmup_rps_median"] = Array.new(curve_len) { |i| stats(results.map { it["warmup_rps"][i] })[:median] }
    unless results.first["parallel"].empty?
      per_run = results.map { speedups(it["parallel"]) }
      out["speedup"] = per_run.first.keys.to_h { |t| [t, stats(per_run.map { it[t] })] }
    end
    out
  end

  def load(path) = JSON.parse(File.read(path))
end
