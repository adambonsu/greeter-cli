# Tasks

## 1. Extract and publish greeter-core

- [x] 1.1 Extract `lib/greeter/domain`, `lib/greeter/ports`, `fake_clock`, and `fixed_clock` into the `greeter-core` repo (history preserved via `git filter-repo`), renaming to `Greeter::Core::Domain` / `Greeter::Core::Ports` / `Greeter::Core::Testing`
- [x] 1.2 Scaffold the gem shell (gemspec, loaders, RSpec/RuboCop config) and publish `greeter-core` to RubyGems

## 2. Consume the gem in this app

- [x] 2.1 Add `gem 'greeter-core', '~> 0.1'` to the `Gemfile`; `bundle install` and confirm the lockfile resolves 0.1.2
- [x] 2.2 Remove the extracted source (`lib/greeter/domain`, `lib/greeter/ports`, `lib/greeter/adapters/fake_clock.rb`, `spec/support/fixed_clock.rb`) and the extracted specs
- [x] 2.3 Rewire references to `Greeter::Core::*` in `exe/greeter`, `lib/greeter/adapters/cli_presenter.rb` (superclass), `features/support/env.rb`, `perf/greeting_bench.rb`, and remaining specs
- [x] 2.4 Update `spec/spec_helper.rb` SimpleCov groups, `.rubocop.yml`, and `AGENTS.md` to the adapter-only surface

## 3. Sync OpenSpec

- [x] 3.1 Narrow `openspec/specs/greeting/cli-greeter/spec.md` to CLI-observable requirements; reference `greeter-core` for validation rules
- [x] 3.2 Remove the latency scenario from `features/greeting.feature` and its step definitions (relocated to the gem's benchmark)
- [x] 3.3 Update `openspec/config.yaml` context and `AGENTS.md` traceability to CLI/Cucumber-specific

## 4. Verify

- [x] 4.1 `bundle exec rspec` green (28 examples, 0 failures)
- [x] 4.2 `bundle exec cucumber` green (5 scenarios, 16 steps)
- [x] 4.3 `bundle exec rubocop` clean
- [x] 4.4 `openspec validate --all --strict` passes
