# frozen_string_literal: true

require 'dry/cli'

# Import subcommands like this
require_relative '../../services/modify_script'

module AlcesJob
  module CLI
    module Commands
      class Modify < Dry::CLI::Command
        AlcesJob::CLI.register 'modify', self
        desc 'This will modify a users script based on flags'

        argument :script, required: true, desc: 'The script to modify'

        option :job_name, type: :string,
                          desc: 'Sets the Slurm job name'

        option :nodes, type: :integer,
                       desc: 'Requests the number of compute nodes'

        option :ntasks, type: :integer,
                        desc: 'Specifies the total number of tasks'

        option :cpus_per_task, type: :integer,
                               desc: 'Specifies CPU cores per task'

        option :mem, type: :string,
                     desc: 'Sets the memory requirement for the job, e.g. 4G or 2000M'

        option :time, type: :string,
                      desc: 'Sets the job walltime limit, e.g. 02:00:00 or 1-00:00:00'

        option :partition, type: :string,
                           desc: 'Specifies the Slurm partition or queue to use'

        option :account, type: :string,
                         desc: 'Specifies the Slurm account to charge'

        option :gres, type: :string,
                      desc: 'Specifies generic resources such as GPUs, e.g. gpu:1'

        option :output, type: :string,
                        desc: 'Sets the Slurm stdout file path'

        option :error, type: :string,
                       desc: 'Sets the Slurm stderr file path'

        option :mail_user, type: :string,
                           desc: 'Sets the email address for Slurm notifications'

        option :mail_type, type: :string,
                           desc: 'Sets the Slurm mail notification type, e.g. BEGIN, END, FAIL'

        option :array, type: :string,
                       desc: 'Sets a Slurm array task specification'

        option :dependency, type: :string,
                            desc: 'Sets a Slurm dependency string'

        option :modules, type: :array, default: [],
                         desc: 'Loads one or more environment modules before running the job'

        option :workdir, type: :string,
                         desc: 'Changes to the specified working directory in the job script'

        option :command, type: :string,
                         desc: 'Specifies the shell command to execute in the script'

        option :output_file, type: :string,
                             desc: 'Writes the modified script to this output filename'

        option :submit, type: :boolean, default: false,
                        desc: 'Submits the script to Slurm automatically'

        def call(script:, **options)
          AlcesJob::Services::ModifyScript.new(
            script: script,
            options: options
          ).call
        end
      end
    end
  end
end
