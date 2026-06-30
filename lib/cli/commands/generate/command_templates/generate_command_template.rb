# frozen_string_literal: true

require 'dry/cli'

module AlcesJob
  module CLI
    module Commands
      module Templates
        class GenerateCommandTemplate < Dry::CLI::Command
          option :job_name, type: :string, aliases: ['-J'], desc: 'Set the job name shown in Slurm'
          option :mem, type: :string, desc: 'Request memory for the job (for example: 4G or 2000M)'
          option :time, type: :string, aliases: ['-t'], desc: 'Set the maximum runtime for the job e.g. 02:00:00 or 1-00:00:00'
          option :partition, type: :string, aliases: ['-p'], desc: 'Choose which Slurm partition (queue) to run on'
          option :module, type: :array, aliases: ['-m'], default: [], desc: 'Load one or more environment modules before running the job'
          option :workdir, type: :string, desc: 'Run the job from the specified working directory'
          option :command, type: :string, desc: 'Command to run in the job script'
          option :account, type: :string, aliases: ['-A'], desc: 'Charge the job to the specified Slurm account'
          option :output_file, type: :string, aliases: ['-o'], desc: 'Save the generated job script to this file'
          option :error, type: :string, aliases: ['-e'], desc: 'Write standard error to this file'
          option :mail_user, type: :string, desc: 'Email address for job notifications'
          option :mail_type, type: :string, desc: 'When to send email notifications (for example: BEGIN, END, or FAIL)'
          option :submit, type: :boolean, default: false, desc: 'Submit the generated job script to Slurm automatically'
          option :profile, type: :string, desc: 'Load settings from a saved profile'
          option :site_config, type: :boolean, default: true, desc: 'Use the site-wide configuration (enabled by default)'
          option :yes, type: :boolean, default: false, desc: 'Skip the confirmation prompt when submitting'
          option :dry_run, type: :boolean, default: false, desc: 'Preview the generated script without saving it'
        end
      end
    end
  end
end