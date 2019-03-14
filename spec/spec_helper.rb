$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

HOST = ENV['TEST_HOST']
USER = ENV['TEST_USER'] || ENV['USER']

if HOST.nil? || USER.nil?
  warn 'TEST_HOST and TEST_USER must be provided.'
  exit 1
end

TEST_ROOT = File.expand_path(__dir__)

RSpec.configure do |config|
  config.color = true

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
