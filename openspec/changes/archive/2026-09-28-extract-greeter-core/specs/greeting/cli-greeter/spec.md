# Spec Delta

## Purpose

Narrow the `cli-greeter` capability to CLI-observable behaviour after the domain
core is extracted into the `greeter-core` gem. Name-validation rules move to
`greeter-core` and are referenced here rather than re-specified; the in-process
latency guarantee moves to `greeter-core` entirely.

## MODIFIED Requirements

### Requirement: Greets a named guest
The CLI SHALL accept a guest name as its first argument, construct a greeting
through `greeter-core`, and emit a formatted greeting line to stdout with
exit code 0.

#### Scenario: Greets a named guest
- **WHEN** the CLI is invoked with a valid guest name (e.g. `greeter Alice`)
- **THEN** the process exits 0 and stdout contains `Hello, Alice!`

### Requirement: Presents normalised casing and whitespace
The CLI SHALL present the guest name using the normalised `display` value from
`greeter-core` (surrounding whitespace stripped, title-cased). The
normalisation rule itself is owned by the `greeter-core` `greeting-core`
capability.

#### Scenario: Presents normalised casing and whitespace
- **WHEN** the CLI is invoked with a name that has surrounding whitespace or non-title casing (e.g. `greeter "  alice smith  "`)
- **THEN** the process exits 0 and stdout contains `Hello, Alice Smith!`

### Requirement: Surfaces an empty or whitespace-only name as an error
The CLI SHALL exit 2 with a human-readable message on stderr and empty stdout
when `greeter-core` rejects the name as empty or whitespace-only. The rejection
rule is owned by `greeter-core`; this requirement covers only how the CLI
surfaces it.

#### Scenario: Rejects an empty or whitespace-only name
- **WHEN** the CLI is invoked with an empty string or a string of only whitespace (e.g. `greeter ""`)
- **THEN** the process exits 2, stderr contains a message indicating the name is invalid, and stdout is empty

### Requirement: Surfaces an over-long name as an error
The CLI SHALL exit 2 with a human-readable message on stderr when `greeter-core`
rejects a name longer than 64 characters after stripping. The length rule is
owned by `greeter-core`.

#### Scenario: Rejects a name longer than 64 characters
- **WHEN** the CLI is invoked with a name longer than 64 characters after stripping
- **THEN** the process exits 2 and stderr contains a message indicating the name is too long

### Requirement: Surfaces control/escape characters as an error
The CLI SHALL exit 2 with a human-readable message on stderr when `greeter-core`
rejects a name containing ASCII control characters (0x00–0x1F, 0x7F) or escape
sequences. This defends against log-injection at the terminal boundary; the
character rule is owned by `greeter-core`.

#### Scenario: Rejects names containing control or escape characters
- **WHEN** the CLI is invoked with a name containing a control character or escape sequence (e.g. a name with `\x1b[`)
- **THEN** the process exits 2 and stderr contains a message indicating the name contains invalid characters

## REMOVED Requirements

### Requirement: Emits the greeting within latency budget
**Reason**: The latency guarantee is a domain-core property of
`GreetingService#greet`, exercisable without any adapter. It moves to the
`greeter-core` `greeting-core` capability (verified by that gem's
`spec/benchmarks/greeting_service_bench.rb`), so this CLI capability no longer
owns it.
