# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

require_relative '../../../services/tracking/tracking_methods'

module AlcesJob
  module CLI
    module Commands
      class JobStatus < Dry::CLI::Command
        AlcesJob::CLI.register 'job status', self
        desc 'Get the status of jobs'

        argument :job_id, required: true, desc: 'The ID of the job'

        option :verbose, type: :boolean, aliases: ['-v'], default: false, desc: 'Show detailed stage information'
        option :live, type: :boolean, default: false, desc: 'Show Live info about the status of the job'

        def call(job_id:, **options)
          verbose = options[:verbose]
          live = options[:live]

          pastel = Pastel.new

          unless live
            data = Services::Tracking.load_job_status(job_id)

            table = Services::Tracking.generate_table(data, verbose)

            puts table
            exit(0)
          end

          system('clear')

          loop do
            data = Services::Tracking.load_job_status(job_id, silent: true)

            table = Services::Tracking.generate_table(data, verbose)

            if data['endTime']
              system('clear')
              puts table
              exit(0)
            end

            print "\e[H"
            puts table
            puts 'Press CTRL-C to exit'
            sleep(0.3)
          end

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          warn pastel.red("\nAn unexpected error occurred while running the command.")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
