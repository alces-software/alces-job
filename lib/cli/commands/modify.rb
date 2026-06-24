# frozen_string_literal: true

require 'dry/cli'

require_relative '../../services/modify_script'

module AlcesJob
  module CLI
    module Commands
      class Modify < Dry::CLI::Command
        AlcesJob::CLI.register 'modify', self
        desc 'This will modify a users script based on flags'

        argument :script, required: true, desc: 'The script to modify'

        option :job_name, aliases: ['-j'], type: :string,
                          desc: 'Sets the Slurm job name'

        option :nodes, aliases: ['-N'], type: :integer,
                       desc: 'Requests the number of compute nodes'

        option :ntasks, aliases: ['-n'], type: :integer,
                        desc: 'Specifies the total number of tasks'

        option :cpus_per_task, aliases: ['-c'], type: :integer,
                               desc: 'Specifies CPU cores per task'

        option :mem, type: :string,
                     desc: 'Sets the memory requirement for the job, e.g. 4G or 2000M'

        option :time, aliases: ['-t'], type: :string,
                      desc: 'Sets the job walltime limit, e.g. 02:00:00 or 1-00:00:00'

        option :partition, aliases: ['-p'], type: :string,
                           desc: 'Specifies the Slurm partition or queue to use'

        option :account, aliases: ['-A'], type: :string,
                         desc: 'Specifies the Slurm account to charge'

        option :gres, type: :string,
                      desc: 'Specifies generic resources such as GPUs, e.g. gpu:1'

        option :output, type: :string,
                        desc: 'Sets the Slurm stdout file path'

        option :error, aliases: ['-e'], type: :string,
                       desc: 'Sets the Slurm stderr file path'

        option :mail_user, type: :string,
                           desc: 'Sets the email address for Slurm notifications'

        option :mail_type, type: :string,
                           desc: 'Sets the Slurm mail notification type, e.g. BEGIN, END, FAIL'

        option :array, type: :string,
                       desc: 'Sets a Slurm array task specification'

        option :dependency, type: :string,
                            desc: 'Sets a Slurm dependency string'

        option :module, type: :array, default: [],
                        desc: 'Loads one or more environment modules before running the job'

        option :workdir, type: :string,
                         desc: 'Changes to the specified working directory in the job script'

        option :command, type: :string,
                         desc: 'Specifies the shell command to execute in the script'

        option :output_file, aliases: ['-o'], type: :string,
                             desc: 'Writes the modified script to this output filename'

        option :submit, type: :boolean, default: false,
                        desc: 'Submits the script to Slurm automatically'

        def call(script:, **options)
          options[:module] = extract_modules(ARGV)

          AlcesJob::Services::ModifyScript.new(
            script: script,
            options: options
          ).call
        rescue StandardError => e
          puts pastel.red("\nAn error occurred while running the command:\n#{e.message}\n")
          exit(1)
        end

        private

        # Takes in the options and combines all the module options into one
        # @param [Hash] argv
        # @return [hash]
        def extract_modules(argv)
          modules = []

          argv.each_with_index do |arg, index|
            value =
              if ['--module', '-m'].include?(arg)
                argv[index + 1]
              elsif arg.start_with?('--module=', '-m=')
                arg.split('=', 2).last
              end

            next unless value

            value
              .split(',')
              .map(&:strip)
              .reject(&:empty?)
              .each { |mod| modules << mod }
          end

          modules
        end
      end
    end
  end
end
