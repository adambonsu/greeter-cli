# frozen_string_literal: true

# Usage:
#   bundle exec ruby perf/greeting_bench.rb
#
# First run writes perf/baseline.json.
# Subsequent runs compare against it and exit non-zero if p99 regresses > 20%.

require 'json'
require 'time'
require 'stringio'
require 'benchmark/ips'

$LOAD_PATH.unshift(File.join(__dir__, '..', 'lib'))

require 'greeter/core'
require 'greeter/core/testing'
require 'greeter/adapters/cli_presenter'

BASELINE_PATH = File.join(__dir__, 'baseline.json')
BUDGET_MS = 5.0
REGRESSION_THRESHOLD = 1.20 # 20% worse than baseline triggers failure
SAMPLE_COUNT = 100_000
# Below this, p99 is dominated by clock resolution and jitter, so a relative
# regression check is meaningless (a single tick reads as ">100% worse").
# The absolute BUDGET_MS gate still applies regardless.
NOISE_FLOOR_MS = 0.05

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def p99(samples_ms)
  sorted = samples_ms.sort
  sorted[(SAMPLE_COUNT * 0.99).ceil - 1]
end

def sample_ms(iterations, &block)
  Array.new(iterations) do
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    block.call
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0
  end
end

# ---------------------------------------------------------------------------
# Object graph
# ---------------------------------------------------------------------------

clock     = Greeter::Core::Testing::FixedClock.new(Time.utc(2024, 6, 1, 9, 0, 0))
service   = Greeter::Core::Domain::GreetingService.new(clock: clock)

output    = StringIO.new
presenter = Greeter::Adapters::CliPresenter.new(output: output)

# ---------------------------------------------------------------------------
# benchmark-ips — throughput report
# ---------------------------------------------------------------------------

puts '=' * 60
puts 'Throughput (benchmark-ips)'
puts '=' * 60

Benchmark.ips do |x|
  x.config(time: 3, warmup: 1)

  x.report('domain: GreetingService#greet') do
    service.greet('Alice')
  end

  x.report('full CLI path (greet + present to StringIO)') do
    output.truncate(0)
    output.rewind
    greeting = service.greet('Alice')
    presenter.present(greeting)
  end

  x.compare!
end

# ---------------------------------------------------------------------------
# p99 latency — domain path
# ---------------------------------------------------------------------------

puts
puts '=' * 60
puts "p99 latency over #{SAMPLE_COUNT} samples"
puts '=' * 60

# Warm up
1_000.times { service.greet('Alice') }

domain_samples = sample_ms(SAMPLE_COUNT) { service.greet('Alice') }
domain_p99     = p99(domain_samples)

cli_samples = sample_ms(SAMPLE_COUNT) do
  output.truncate(0)
  output.rewind
  presenter.present(service.greet('Alice'))
end
cli_p99 = p99(cli_samples)

puts format('  domain p99 : %.4f ms', domain_p99)
puts format('  cli    p99 : %.4f ms', cli_p99)

# ---------------------------------------------------------------------------
# Budget gate
# ---------------------------------------------------------------------------

failures = []
if domain_p99 >= BUDGET_MS
  failures << format('domain p99 %<p99>.4f ms exceeds %<budget>.1f ms budget', p99: domain_p99, budget: BUDGET_MS)
end
if cli_p99 >= BUDGET_MS
  failures << format('cli p99 %<p99>.4f ms exceeds %<budget>.1f ms budget', p99: cli_p99, budget: BUDGET_MS)
end

# ---------------------------------------------------------------------------
# Baseline write / regression check
# ---------------------------------------------------------------------------

results = {
  'recorded_at' => Time.now.utc.iso8601,
  'domain_p99_ms' => domain_p99.round(6),
  'cli_p99_ms' => cli_p99.round(6)
}

if File.exist?(BASELINE_PATH)
  baseline = JSON.parse(File.read(BASELINE_PATH))
  puts
  puts '=' * 60
  puts "Regression check (threshold: #{((REGRESSION_THRESHOLD - 1) * 100).round}% worse than baseline)"
  puts '=' * 60
  puts format('  baseline domain p99 : %.4f ms', baseline['domain_p99_ms'])
  puts format('  baseline cli    p99 : %.4f ms', baseline['cli_p99_ms'])

  baseline_domain = baseline['domain_p99_ms']
  baseline_cli = baseline['cli_p99_ms']

  if baseline_domain >= NOISE_FLOOR_MS && domain_p99 > baseline_domain * REGRESSION_THRESHOLD
    failures << format(
      'domain p99 %<p99>.4f ms is >%<pct>.0f%% worse than baseline %<baseline>.4f ms',
      p99: domain_p99, pct: (REGRESSION_THRESHOLD - 1) * 100, baseline: baseline_domain
    )
  end

  if baseline_cli >= NOISE_FLOOR_MS && cli_p99 > baseline_cli * REGRESSION_THRESHOLD
    failures << format(
      'cli p99 %<p99>.4f ms is >%<pct>.0f%% worse than baseline %<baseline>.4f ms',
      p99: cli_p99, pct: (REGRESSION_THRESHOLD - 1) * 100, baseline: baseline_cli
    )
  end

  if baseline_domain < NOISE_FLOOR_MS || baseline_cli < NOISE_FLOOR_MS
    puts format(
      '  (regression check skipped where baseline < %<floor>.2f ms noise floor)',
      floor: NOISE_FLOOR_MS
    )
  end
else
  File.write(BASELINE_PATH, JSON.pretty_generate(results))
  puts
  puts "Baseline written to #{BASELINE_PATH}"
end

# ---------------------------------------------------------------------------
# Exit
# ---------------------------------------------------------------------------

puts
if failures.empty?
  puts 'All checks passed.'
else
  puts 'FAILURES:'
  failures.each { |f| puts "  - #{f}" }
  exit 1
end
