# frozen_string_literal: true

require 'dry/cli'

require_relative '../alces_job/version'

module AlcesJob
  module CLI
    extend Dry::CLI::Registry
  end
end

# Load commands (only used to load top level commands sub commands are loaded within the commands)
require_relative 'commands/version'
require_relative 'commands/command'
