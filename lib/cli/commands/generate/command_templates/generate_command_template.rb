# frozen_string_literal: true

require 'dry/cli'

module AlcesJob
  module CLI
    module Commands
      module Templates
        class GenerateCommandTemplate < Dry::CLI::Command
          option :job_name, type: :string, aliases: ['-J'],
                            desc: 'Sets the Slurm job name for the generated Serial script'

          option :mem, type: :string,
                       desc: 'Sets the memory requirement for the job (e.g. 4G or 2000M)'

          option :time, type: :string, aliases: ['-t'],
                        desc: 'Sets the walltime limit for the Serial job'

          option :partition, type: :string, aliases: ['-p'],
                             desc: 'Specifies the Slurm partition or queue to use'

          option :module, type: :array, default: [],
                          desc: 'Loads environment modules before running the job'

          option :workdir, type: :string,
                           desc: 'Changes to the specified working directory in the job script'

          option :command, type: :string,
                           desc: 'Specifies the shell command to execute in the script'

          option :account, type: :string, aliases: ['-A'],
                           desc: 'Specifies the Slurm account to charge'

          option :output_file, type: :string, aliases: ['-o'],
                               desc: 'Writes the generated script to this output filename'

          option :error, type: :string, aliases: ['-e'],
                         desc: 'Sets the Slurm stderr file path in the generated script'

          option :mail_user, type: :string,
                             desc: 'Sets the email address for Slurm notifications'

          option :mail_type, type: :string,
                             desc: 'Sets the Slurm mail notification type (BEGIN, END, FAIL, etc.)'

          option :submit, type: :boolean, default: false,
                          desc: 'Makes it so the SBATCH script that is generated is submitted to slurm automatically'
          option :profile, type: :string,
                           desc: 'The name of a profile you have stored to load predetermined flags'

          option :site_config, type: :boolean, default: true, desc: 'whether or not to use the admins specified config file'

          option :yes, type: :boolean, default: false,
                       desc: 'Submits the generated script without prompting'

          option :dry_run, type: :boolean, default: false,
                           desc: 'Does not save the file if set to true'

          private

          def normalize_module_options!(options, argv = ARGV)
            modules = extract_modules(argv)
            modules = Array(options[:module]) if modules.empty?

            options[:module] = modules
              .map(&:to_s)
              .map(&:strip)
              .reject(&:empty?)
              .uniq
          end

          def remove_empty_module_default!(options)
            options.delete(:module) if options[:module].respond_to?(:empty?) && options[:module].empty?
          end

          def extract_modules(argv)
            modules = []

            argv.each_with_index do |arg, index|
              if ['--module', '-m'].include?(arg)
                value = argv[index + 1]
                modules << value if value && !value.start_with?('-')
              elsif arg.start_with?('--module=', '-m=')
                modules << arg.split('=', 2).last
              end
            end

            modules
          end
        end
      end
    end
  end
end
