# frozen_string_literal: true

require 'mongoid-rspec'
require 'timecop'

require "periodic_job_mongoid"

ENV['MONGOID_ENV'] = 'test'
Mongoid.load! 'mongoid.yml'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include Mongoid::Matchers, type: :model

  config.before :each do
    Mongoid.purge!
  end
end
