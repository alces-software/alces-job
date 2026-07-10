# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

module AlcesJob
  module CLI
    module Commands
      class JobTracking < Dry::CLI::Command
        AlcesJob::CLI.register 'job tracking', self

        desc 'Get the location of the tracking functions so they can be manually sourced'

        option :pretty, type: :boolean, aliases: ['-p'], default: false, desc: 'Output data in a nicer format'

        def call(**options)
          pastel = Pastel.new
          spec = Gem.loaded_specs['alces-job']

          unless spec
            warn pastel.red("\nCould not locate gem environment. Are you sure you have installed the gem?\n")
            exit(1)
          end

          lib_path = File.join(spec.full_gem_path, 'lib/helper_functions/functions.bash')
          job_path = Services::Paths.new.user_job_dir
          path_var = 'ALCES_HOMEPATH'
          stage_var = 'ALCES_TOTAL_STAGES'
          source_text = 'source'
          export_text = 'export'

          if options[:pretty]
            lib_path = pastel.blue(lib_path)
            job_path = pastel.blue(job_path)

            path_var = pastel.magenta(path_var)
            stage_var = pastel.magenta(stage_var)

            source_text = pastel.cyan(source_text)
            export_text = pastel.cyan(export_text)

            puts "\nPut the following methods into your job script file to allow use of the helper methods:\n\n"
          end
          puts "#{source_text} #{lib_path}"
          puts "#{export_text} #{path_var}=#{job_path}"
          puts "#{export_text} #{stage_var}=0"
        end
      end
    end
  end
end
