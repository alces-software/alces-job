# frozen_string_literal: true

require 'dry/cli'
require 'yaml'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'

module AlcesJob
  module CLI
    module Commands
      class ProfileCreate < Dry::CLI::Command
        AlcesJob::CLI.register 'profile create', self
        desc 'This command creates a profile bases on the flags passed in'

        option :profile_name, type: :string

        option :job_name, type: :string
        option :nodes, type: :integer
        option :ntasks, type: :integer
        option :cpus_per_task, type: :integer
        option :mem, type: :string

        option :time, type: :string
        option :partition, type: :string
        option :account, type: :string

        option :mail_user, type: :string
        option :mail_type, type: :string

        option :workdir, type: :string

        def initialize
          config = YAML.load_file(File.expand_path('../../../../config.yaml', __dir__))
          @profile_dir = config['user_profile_dir']
        end

        def call(**options)
          pastel = Pastel.new
          prompt = TTY::Prompt.new

          return puts pastel.red("\nNo profile name was provided\n") if options[:profile_name].nil?

          profile_name = options[:profile_name].strip
          profile_path = "#{@profile_dir}/#{profile_name}.yaml"
          options.delete(:profile_name)

          return puts pastel.red("\nNo flags were provided that could be saved to a profile\n") if options.empty?

          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✔'),
            error_mark: pastel.red('✖')
          )
          spinner.update(title: 'generating profile')
          spinner.auto_spin

          if File.exist?(profile_path)
            spinner.error('(profile exists)')
            return unless prompt.yes?("\nA profile with that name was found do you want to overwrite it?", default: false)

            puts
            spinner.update(title: 'overwriting profile')
            spinner.auto_spin
          end

          FileUtils.mkdir_p(File.dirname(@profile_dir))
          File.write(profile_path, options.to_yaml)

          spinner.success('(successful)')

          puts pastel.green("\nYour profile has been created and written to #{profile_path}\n")
        end
      end
    end
  end
end
