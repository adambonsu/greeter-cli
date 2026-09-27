# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(__dir__, '..', '..', 'lib'))

require 'stringio'
require 'greeter/core'
require 'greeter/core/testing'
require 'greeter/adapters/cli_presenter'

module GreeterWorld
  def stdout_io
    @stdout_io ||= StringIO.new
  end

  def stderr_io
    @stderr_io ||= StringIO.new
  end

  def fixed_clock
    @fixed_clock ||= Greeter::Core::Testing::FixedClock.new(Time.utc(2024, 6, 1, 9, 0, 0))
  end

  def presenter
    @presenter ||= Greeter::Adapters::CliPresenter.new(output: stdout_io)
  end

  def service
    @service ||= Greeter::Core::Domain::GreetingService.new(clock: fixed_clock)
  end

  def invoke_cli(raw_name)
    @exit_code = 0
    service.greet(raw_name).tap { |g| presenter.present(g) }
  rescue Greeter::Core::Domain::InvalidGuestName => e
    @exit_code = 2
    stderr_io.puts(e.message)
  end

  def exit_code
    @exit_code ||= 0
  end
end

World(GreeterWorld)
