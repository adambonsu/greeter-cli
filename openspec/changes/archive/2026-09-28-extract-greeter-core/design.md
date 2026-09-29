# Design

## Context

The `2026-09-25-add-hello-world-greeting` change delivered domain, ports, and
adapters as a single repository. All domain/ports code was already pure (zero
gems, zero I/O, no `Time.now`), so it was extractable without behavioural change.
This change performs that extraction and rewires the app to consume the result.

## Goals / Non-Goals

**Goals:**
- Make the domain core reusable and independently versioned as a published gem.
- Keep this repository a thin adapter app that depends on the gem.
- Preserve all existing behaviour; the CLI's observable contract is unchanged.

**Non-Goals:**
- No behavioural change to validation, greeting construction, or presentation.
- No new adapters (HTTP/Lambda/DynamoDB remain future work).

## Decisions

### D1: Namespace becomes Greeter::Core

`Greeter::Domain` → `Greeter::Core::Domain`; `Greeter::Ports` →
`Greeter::Core::Ports`. The extra `Core` segment names the gem's boundary and
avoids collision with app-level `Greeter::Adapters` in consumers.

### D2: Test doubles ship in the gem under Greeter::Core::Testing

`FakeClock` and `FixedClock` (previously an app adapter and a spec-support file)
are consolidated under `Greeter::Core::Testing` and shipped in the gem's `lib/`,
loaded on demand with `require 'greeter/core/testing'` — never from the
production load path (`require 'greeter/core'`), keeping production I/O-free.

### D3: SystemClock stays in the app

`SystemClock#now` performs real I/O (`Time.now.utc`) and its spec asserts a
wall-clock timing property that is inherently non-deterministic. Keeping it in
the app preserves the gem's fully deterministic, I/O-free test suite and mirrors
the symmetry of the app owning its driven adapters (`CliPresenter`).

### D4: Depend on the published gem via a pessimistic constraint

`gem 'greeter-core', '~> 0.1'` allows patch and minor 0.x updates while the API
stabilises. The lockfile pins the exact resolved version (0.1.2).

### D5: cli-greeter narrowed; rules referenced, not duplicated

The CLI capability now specifies only CLI-observable behaviour. Each validation
requirement states the CLI's surfacing contract (exit 2 + stderr) and names
`greeter-core` as the owner of the underlying rule, so there is a single source
of truth per rule across the two repos.

## Migration Plan

1. Extract domain/ports/testing into `greeter-core` (history preserved via
   `git filter-repo`), rename to `Greeter::Core::*`, publish to RubyGems.
2. In this app: remove the extracted files, rewire references to `Greeter::Core`,
   depend on the gem, narrow the `cli-greeter` spec, and relocate the latency
   guarantee to the gem's OpenSpec.
3. Verify: `bundle install`, RSpec, Cucumber, RuboCop, and `openspec validate`.

## Risks / Trade-offs

- A `~> 0.1` constraint permits 0.x minor bumps that may include breaking changes
  (SemVer permits breakage below 1.0). The lockfile mitigates surprise; bumps are
  deliberate via `bundle update greeter-core`.
- Cross-repo traceability now spans two OpenSpec suites (CLI → Cucumber, core →
  RSpec). The "own where enforced, reference where observed" convention keeps
  rules from drifting.

## Open Questions

_(none)_
