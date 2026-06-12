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

# Loads all profile commands
require_relative 'commands/profile'

# Loads all template commands
require_relative 'commands/template'

# Loads interactive command
require_relative 'commands/interactive'

# Loads all commands used to make sbatch scripts
require_relative 'commands/base'
require_relative 'commands/serial'
require_relative 'commands/gpu'
require_relative 'commands/mpi'
require_relative 'commands/array'
<<<<<<< HEAD
require_relative 'commands/config'
require_relative 'commands/validate'
require_relative 'commands/interactive'
require_relative 'commands/tvalidate'
=======
>>>>>>> main
