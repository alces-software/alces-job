# frozen_string_literal: true

require 'dry/cli'
require 'yaml'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'
require 'fileutils'

module AlcesJob
  module CLI
    module Commands
      class ProfileCreate < Dry::CLI::Command
        AlcesJob::CLI.register 'profile create', self
        desc 'This command creates a profile bases on the flags passed in'

        option :profile_name, type: :string, desc: 'What the profile will be called'

        option :job_name, type: :string,
                          desc: 'Sets the Slurm job name for the generated script'
        option :nodes, type: :integer,
                       desc: 'Requests the number of compute nodes for the job'
        option :ntasks, type: :integer,
                        desc: 'Specifies the total number of tasks for the job'
        option :cpus_per_task, type: :integer,
                               desc: 'Specifies CPU cores per task'
        option :mem, type: :string,
                     desc: 'Sets the memory requirement for the job (e.g. 4G or 2000M)'

        option :time, type: :string,
                      desc: 'Sets the job time limit (e.g. 02:00:00)'
        option :partition, type: :string,
                           desc: 'Specifies the Slurm partition or queue to use'
        option :account, type: :string,
                         desc: 'Specifies the Slurm account to charge'

        option :mail_user, type: :string,
                           desc: 'Sets the email address for Slurm notifications'
        option :mail_type, type: :string,
                           desc: 'Sets the Slurm mail notification type (BEGIN, END, FAIL, etc.)'

        option :workdir, type: :string,
                         desc: 'Changes to the specified working directory in the job script'

        def initialize
          @config_path = YAML.load_file(File.expand_path('../../../../config.yaml', __dir__))['admin_config_file']
        end

        def call(**options)
          pastel = Pastel.new
          prompt = TTY::Prompt.new

          if options[:profile_name].nil?
            puts pastel.red("\nNo profile name was provided\n")
            exit(1)
          end

          profile_name = options[:profile_name].strip
          profile_path = "#{@profile_dir}/#{profile_name}.yaml"
          options.delete(:profile_name)

          if options.empty?
            puts pastel.red("\nNo flags were provided that could be saved to a profile\n")
            exit(1)
          end

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

            exit(0) unless prompt.yes?("\nA profile with that name was found do you want to overwrite it?", default: false)

            puts
            spinner.update(title: 'overwriting profile')
            spinner.auto_spin
          end

          begin
            FileUtils.mkdir_p(File.dirname(@profile_dir))
            File.write(profile_path, options.to_yaml)
            spinner.success('(successful)')

            puts pastel.green("\nYour profile has been created and written to #{profile_path}\n")
            exit(0)
          rescue StandardError => e
            spinner.error('(writing error)')
            puts pastel.green("\nFailed to create your profile: #{e.message}\n")
            exit(1)
          end
        end
      end
    end
  end
end
