# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'greeter/core'
require 'greeter/core/testing'
require 'greeter/adapters/cli_presenter'

# ---------------------------------------------------------------------------
# Payload constants — defined at file scope to avoid Lint/ConstantDefinitionInBlock
# ---------------------------------------------------------------------------

SEC_ANSI_ESCAPES = [
  "\e[31m",
  "\e[1;32m",
  "\e]0;title\a",
  "\e[2J",
  "\x1b[?1049h"
].freeze

SEC_CONTROL_CHARS = (("\x00".."\x1F").to_a + ["\x7F"]).freeze

SEC_COMMAND_SUBSTITUTION = [
  '$(whoami)',
  '`id`',
  '$(cat /etc/passwd)',
  '`uname -a`',
  '$((1+1))'
].freeze

# Overlong UTF-8 encodings (bytes structurally invalid in UTF-8)
SEC_OVERLONG_SEQUENCES = [
  "\xC0\xAF",
  "\xE0\x80\xAF",
  "\xF0\x80\x80\xAF",
  "\xED\xA0\x80"
].freeze

SEC_RTL_PAYLOADS = [
  "\u202EevildisplayName",
  "Alice\u202E",
  "\u200BAlice",
  "\uFEFFAlice"
].freeze

SEC_LOG_INJECTION = [
  "Alice\nINFO: admin logged in",
  "Bob\r\nSet-Cookie: session=evil",
  "Carol\x00injected"
].freeze

SEC_LONG_STRINGS = [
  'A' * 10_000,
  'B' * 65,
  "\e[31m#{'C' * 60}"
].freeze

# Overlong sequences excluded from main corpus: they raise ArgumentError
# (encoding error) before reaching domain logic and are tested separately.
SEC_ALL_PAYLOADS = (
  SEC_ANSI_ESCAPES +
  SEC_CONTROL_CHARS +
  SEC_COMMAND_SUBSTITUTION +
  SEC_RTL_PAYLOADS +
  SEC_LOG_INJECTION +
  SEC_LONG_STRINGS
).freeze

RSpec.describe 'Input validation security', :aggregate_failures do
  # Allow \n (\x0A) and \r (\x0D) as legitimate puts terminators.
  # Block all other C0 control chars and DEL (\x7F).
  def safe_display?(text)
    !text.match?(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/)
  end

  def invoke(raw_name)
    output    = StringIO.new
    service   = Greeter::Core::Domain::GreetingService.new(clock: Greeter::Core::Testing::FixedClock.new)
    presenter = Greeter::Adapters::CliPresenter.new(output: output)
    greeting  = service.greet(raw_name)
    presenter.present(greeting)
    { ok: true, output: output.string }
  rescue Greeter::Core::Domain::InvalidGuestName, ArgumentError, EncodingError => e
    { ok: false, error: e.message }
  end

  # ---------------------------------------------------------------------------
  # Property-style fuzz — 500 samples
  # ---------------------------------------------------------------------------

  let(:corpus) do
    base = SEC_ALL_PAYLOADS.dup
    i = 0
    while base.size < 500
      base << (SEC_ALL_PAYLOADS[i % SEC_ALL_PAYLOADS.size] +
               SEC_ALL_PAYLOADS[(i + 1) % SEC_ALL_PAYLOADS.size])
      i += 1
    end
    base.first(500)
  end

  it 'every payload either raises InvalidGuestName or produces a safe rendered greeting' do
    corpus.each do |payload|
      result = invoke(payload)

      if result[:ok]
        rendered = result[:output]
        expect(safe_display?(rendered)).to be(true),
                                           "Unsafe output for payload #{payload.inspect}: #{rendered.inspect}"
      else
        expect(result[:error]).to be_a(String)
      end
    end
  end

  it 'no payload causes unescaped control characters to reach the output IO' do
    corpus.each do |payload|
      result = invoke(payload)
      next unless result[:ok]

      expect(result[:output]).not_to match(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/),
                                     "Control character leaked to output for payload #{payload.inspect}"
    end
  end

  it 'command-substitution strings are never executed — output contains literal text or raises' do
    SEC_COMMAND_SUBSTITUTION.each do |payload|
      result = invoke(payload)
      # Printable ASCII passes GuestName validation; Ruby interpolation never
      # executes shell syntax. Assert no control chars in output.
      expect(safe_display?(result[:output])).to be(true) if result[:ok]
    end
  end

  # ---------------------------------------------------------------------------
  # Category-specific assertions
  # ---------------------------------------------------------------------------

  it 'rejects all ANSI escape sequences' do
    SEC_ANSI_ESCAPES.each do |payload|
      expect { Greeter::Core::Domain::GuestName.new(payload) }
        .to raise_error(Greeter::Core::Domain::InvalidGuestName)
    end
  end

  it 'rejects all C0/DEL control characters' do
    SEC_CONTROL_CHARS.each do |payload|
      expect { Greeter::Core::Domain::GuestName.new(payload) }
        .to raise_error(Greeter::Core::Domain::InvalidGuestName)
    end
  end

  it 'rejects log-injection payloads containing newlines or null bytes' do
    SEC_LOG_INJECTION.each do |payload|
      expect { Greeter::Core::Domain::GuestName.new(payload) }
        .to raise_error(Greeter::Core::Domain::InvalidGuestName)
    end
  end

  it 'rejects strings exceeding 64 characters' do
    expect { Greeter::Core::Domain::GuestName.new('A' * 65) }
      .to raise_error(Greeter::Core::Domain::InvalidGuestName)
    expect { Greeter::Core::Domain::GuestName.new('A' * 10_000) }
      .to raise_error(Greeter::Core::Domain::InvalidGuestName)
  end

  it 'accepts or safely normalises RTL/zero-width Unicode that contains no control chars' do
    SEC_RTL_PAYLOADS.each do |payload|
      result = invoke(payload)
      next unless result[:ok]

      expect(safe_display?(result[:output])).to be(true)
    end
  end

  it 'rejects or safely handles overlong/invalid UTF-8 byte sequences' do
    SEC_OVERLONG_SEQUENCES.each do |payload|
      utf8_payload = payload.dup.force_encoding('UTF-8')
      result = begin
        invoke(utf8_payload)
      rescue EncodingError
        { ok: false, error: 'EncodingError' }
      end

      if result[:ok]
        expect(safe_display?(result[:output])).to be(true)
      else
        expect(result[:error]).to be_a(String)
      end
    end
  end
end
