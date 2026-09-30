require "minitest/autorun"
require "tmpdir"
require_relative "../lib/summary"

class SummaryTest < Minitest::Test
  def test_stats_returns_middle_value_for_odd_count
    assert_equal({ median: 3, min: 1, max: 9, n: 3 }, Summary.stats([9, 1, 3]))
  end

  def test_stats_averages_two_middle_values_for_even_count
    assert_in_delta 2.5, Summary.stats([4, 1, 2, 3])[:median]
  end

  def test_stats_accepts_single_value
    assert_equal({ median: 7, min: 7, max: 7, n: 1 }, Summary.stats([7]))
  end

  def test_stats_rejects_empty_values
    assert_raises(ArgumentError) { Summary.stats([]) }
  end

  def test_speedups_divides_by_single_thread_rps
    got = Summary.speedups([{ "threads" => 1, "rps" => 100.0 }, { "threads" => 4, "rps" => 250.0 }])
    assert_equal({ 1 => 1.0, 4 => 2.5 }, got)
  end

  def test_speedups_rejects_missing_single_thread
    assert_raises(ArgumentError) { Summary.speedups([{ "threads" => 2, "rps" => 10.0 }]) }
  end

  def test_build_aggregates_runs_and_truncates_curve_to_shortest_run
    Dir.mktmpdir do |dir|
      write_run(dir, 1, rps: 10.0, curve: [1, 2, 3], parallel: [{ "threads" => 1, "rps" => 10.0 }, { "threads" => 2, "rps" => 15.0 }])
      write_run(dir, 2, rps: 30.0, curve: [3, 4], parallel: [{ "threads" => 1, "rps" => 10.0 }, { "threads" => 2, "rps" => 25.0 }])
      write_run(dir, 3, rps: 20.0, curve: [5, 6, 7], parallel: [{ "threads" => 1, "rps" => 10.0 }, { "threads" => 2, "rps" => 20.0 }])

      got = Summary.build(dir).fetch("mri")
      w = got[:workloads].fetch("html_index")

      assert_equal "ruby 4.0.7", got[:description]
      assert_equal 20.0, w["rps"][:median]
      assert_equal [3, 4], w["warmup_rps_median"]
      assert_in_delta 2.0, w["speedup"][2][:median]
      assert_equal 100.0, got[:boot_ms][:median]
    end
  end

  def test_build_omits_speedup_when_parallel_not_measured
    Dir.mktmpdir do |dir|
      write_run(dir, 1, rps: 10.0, curve: [1], parallel: [])
      refute Summary.build(dir).fetch("mri")[:workloads].fetch("html_index").key?("speedup")
    end
  end

  private

  def write_run(dir, n, rps:, curve:, parallel:)
    run = File.join(dir, "mri", "run-#{n}")
    FileUtils.mkdir_p(run)
    File.write(File.join(run, "boot.json"), JSON.generate(boot_ms: [90.0, 100.0, 110.0]))
    File.write(File.join(run, "html_index.json"), JSON.generate(
      ruby_description: "ruby 4.0.7", rps: rps, p50_ms: 1.0, p99_ms: 2.0, peak_rss_mb: 100.0,
      warmup_rps: curve, parallel: parallel
    ))
  end
end
