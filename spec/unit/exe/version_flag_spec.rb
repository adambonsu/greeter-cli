# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'greeter/cli/version'
require 'greeter/core'

# The --version flag lives in the executable itself (argv parsing + exit), so
# it is exercised by running the real exe/greeter as a subprocess rather than
# through the in-process object graph used by the other specs.
RSpec.describe 'exe/greeter --version', :aggregate_failures do
  let(:exe) { File.expand_path('../../../exe/greeter', __dir__) }

  def run(*args)
    Open3.capture3(RbConfig.ruby, exe, *args)
  end

  ['--version', '-v'].each do |flag|
    it "prints the CLI and greeter-core versions and exits 0 for #{flag}" do
      stdout, _stderr, status = run(flag)

      expect(status.exitstatus).to eq(0)
      expect(stdout).to include("greeter-cli #{Greeter::Cli::VERSION}")
      expect(stdout).to include("greeter-core #{Greeter::Core::VERSION}")
    end
  end
end
