# frozen_string_literal: true

require 'dry/cli'

require_relative '../alces_job/version'

module AlcesJob
  module CLI
    extend Dry::CLI::Registry
  end
end

# Loads version command
require_relative 'commands/version'

# Loads all config commands
require_relative 'commands/config'

# Loads sysinfo commands
require_relative 'commands/sysinfo'

# Loads all profile commands
require_relative 'commands/profile'

# Loads all template commands
require_relative 'commands/template'

# Loads interactive command
require_relative 'commands/interactive'

# Loads all generator commands
require_relative 'commands/generate'

# Loads all validator commands
require_relative 'commands/validate'

# Load modify command
require_relative 'commands/modify'

# Load completion command
require_relative 'commands/completion'

# Load job status commands
require_relative 'commands/job/status'
require_relative 'commands/job/history'

# Load module commands
require_relative 'commands/module'
