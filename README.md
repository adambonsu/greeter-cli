# greeter-cli

A hexagonal CLI greeter. This is the application layer: it owns the driven
adapters (`CliPresenter`, `SystemClock`) and the composition root
(`exe/greeter`), and depends on the [`greeter-core`](https://rubygems.org/gems/greeter-core)
gem for the pure domain and ports (`Greeter::Core::Domain`, `Greeter::Core::Ports`).

## Requirements

- Ruby 3.3.5
- Bundler

## Setup

```bash
bundle install
bundle exec ruby exe/greeter "Alice"   # => Hello, Alice!
```

## Referencing the greeter-core gem

This app depends on `greeter-core`. Pick the source that matches your workflow
and put **one** of the following in the `Gemfile`, then run `bundle install`.

### RubyGems (default — released versions)

Use the published gem. This is what the committed `Gemfile` uses.

```ruby
gem 'greeter-core', '~> 0.1'
```

`~> 0.1` is a pessimistic constraint: it allows `0.1.x` and later `0.x` releases
while the API stabilises, and `Gemfile.lock` pins the exact resolved version.
Upgrade deliberately with:

```bash
bundle update greeter-core
```

### GitHub (unreleased commits / a branch or tag)

Track the gem's repository directly — useful for testing changes that are merged
but not yet published to RubyGems.

```ruby
# Follow the default branch:
gem 'greeter-core', git: 'https://github.com/adambonsu/greeter-core.git', branch: 'main'

# …or pin to a tag or commit for reproducibility:
gem 'greeter-core', git: 'https://github.com/adambonsu/greeter-core.git', tag: 'v0.1.2'
gem 'greeter-core', git: 'https://github.com/adambonsu/greeter-core.git', ref: 'e6b039c'
```

With a `git:` source, `bundle update greeter-core` re-resolves against the branch
(or leaves a pinned `tag`/`ref` fixed). Bundler records the resolved commit SHA
in `Gemfile.lock`.

### Local path (developing the gem alongside this app)

Point at a local clone so edits in the gem are picked up immediately, with no
publish or push step. Assumes the gem is checked out as a sibling directory.

```ruby
gem 'greeter-core', path: '../greeter-core'
```

Prefer this only for local development — do not commit a `path:` source, since
the path won't exist on CI or another machine. To keep `git:`/RubyGems in the
committed `Gemfile` while overriding to a local checkout on your machine only:

```bash
bundle config set --local local.greeter-core ../greeter-core
```

This requires a `git:` source in the `Gemfile` (Bundler maps the local override
onto it) and leaves the committed `Gemfile` unchanged. Remove it with:

```bash
bundle config unset --local local.greeter-core
```

## Testing

```bash
bundle exec rspec        # unit + security specs
bundle exec cucumber     # CLI behaviour scenarios
bundle exec rubocop      # lint
```

## Architecture

Hexagonal. Dependencies point inward only; adapters depend on `greeter-core`,
and the core never references adapters.

| Layer | Location | Namespace |
|---|---|---|
| Domain | `greeter-core` gem | `Greeter::Core::Domain` |
| Ports | `greeter-core` gem | `Greeter::Core::Ports` |
| Adapters | `lib/greeter/adapters` | `Greeter::Adapters` |

Test doubles (`FakeClock`, `FixedClock`) ship in the gem under
`Greeter::Core::Testing` and load with `require 'greeter/core/testing'`.

See `AGENTS.md` for full project conventions and `openspec/` for the
specification of CLI-observable behaviour.
