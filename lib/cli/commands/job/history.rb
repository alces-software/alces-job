# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

require_relative '../../../services/tracking/tracking_methods'

module AlcesJob
  module CLI
    module Commands
      class History < Dry::CLI::Command
        AlcesJob::CLI.register 'history', self

        option :status,
               type: :string,
               values: %w[running completed],
               desc: 'Filter by job status'

        option :limit,
               type: :integer,
               desc: 'Maximum number of jobs to display'

        option :interactive,
               type: :boolean,
               aliases: ['-i'],
               default: false,
               desc: 'Lets you select a job for more info'

        desc 'Get a history of the jobs'

        def call(status: nil, limit: nil, **options)
          pastel = Pastel.new
          interactive = options[:interactive]

          history = Services::Tracking.get_job_history(
            status: status&.to_sym,
            limit: limit
          )

          if interactive
            Services::Tracking.display_jobs_interactive(history)
          else
            Services::Tracking.display_jobs(history)
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
