# Proposal

## Why

The domain and ports were pure, framework-agnostic Ruby with no I/O, yet they
lived inside the CLI application. Any future consumer (an HTTP/Lambda handler, a
second CLI) would have had to copy or re-reference app-internal files. Extracting
the domain core into a standalone, published gem makes the hexagonal inner
hexagon reusable and independently versioned, and turns this repository into a
thin adapter application (`greeter-cli`) that depends on it.

## What Changes

- Extract `Greeter::Domain` and `Greeter::Ports` into a standalone gem
  `greeter-core`, renamed to `Greeter::Core::Domain` and `Greeter::Core::Ports`.
- Ship the in-memory test doubles (`FakeClock`, `FixedClock`) inside the gem
  under `Greeter::Core::Testing`, loaded via `require 'greeter/core/testing'`.
- This app keeps the driven adapters (`CliPresenter`, `SystemClock`) and the
  composition root (`exe/greeter`); it now depends on `greeter-core` from
  RubyGems (`gem 'greeter-core', '~> 0.1'`).
- Move the domain latency guarantee to `greeter-core`; this app's OpenSpec no
  longer owns it.
- Narrow the `greeting/cli-greeter` capability to CLI-observable behaviour
  (arguments, exit codes, stdout/stderr). Name-validation rules are now owned by
  `greeter-core` and referenced here rather than re-specified.

## Capabilities

### New Capabilities

_(none in this repo — the domain/ports capabilities now live in the greeter-core repo's OpenSpec)_

### Modified Capabilities

- `greeting/cli-greeter`: validation requirements reworded to surface
  `greeter-core` rejections at the CLI boundary; the in-process latency
  requirement removed (relocated to `greeter-core`).

## Impact

- `lib/greeter/domain/` and `lib/greeter/ports/` removed from this repo.
- `lib/greeter/adapters/fake_clock.rb` and `spec/support/fixed_clock.rb` removed
  (relocated into the gem under `Greeter::Core::Testing`).
- Extracted specs (domain, ports, `fake_clock`, latency benchmark) removed from
  this repo; they now live in `greeter-core`.
- New runtime dependency: `greeter-core` (`~> 0.1`, resolved to 0.1.2).
- `CliPresenter` now subclasses `Greeter::Core::Ports::GreetingPresenter`.
- The prior archived change (`2026-09-25-add-hello-world-greeting`) is left
  intact as the historical record of the pre-split monolith.
