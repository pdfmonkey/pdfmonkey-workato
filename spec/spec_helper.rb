# frozen_string_literal: true

require 'byebug'
require 'timecop'
require 'webmock/rspec'
require 'workato-connector-sdk'

module Helpers
  def endpoint(path)
    URI.join(connector.connection.base_uri, path)
  end
end

module JsonPayloads
  def load_payloads
    @payloads = {}.with_indifferent_access

    Dir["#{__dir__}/support/payloads/*.json"].each do |file|
      key = File.basename(file, '.json')
      @payloads[key] = File.read(file)
    end
  end

  def payload(name)
    @payloads.fetch(name)
  end
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = 'spec/.status'
  config.filter_run :focus
  config.run_all_when_everything_filtered = true
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.include Helpers
  config.include JsonPayloads

  config.before(:all) { load_payloads }

  config.around :each, :freeze_time do |example|
    Timecop.freeze('2050-01-02T03:04:05Z') { example.run }
  end
end
