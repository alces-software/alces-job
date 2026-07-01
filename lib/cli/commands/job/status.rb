# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

require_relative '../../../services/tracking/tracking_methods'

module AlcesJob
  module CLI
    module Commands
      class Status < Dry::CLI::Command
        AlcesJob::CLI.register 'status', self

        argument :job_id, required: true, desc: 'The ID of the job'

        option :verbose, type: :boolean, aliases: ['-v'], default: false, desc: 'Show detailed stage information'

        desc 'Get the status of jobs'

        def call(job_id:, **options)
          pastel = Pastel.new

          data = Services::Tracking.load_job_status(job_id)

          table = Services::Tracking.generate_table(data, options[:verbose])

          puts table

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
