# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'
require 'yaml'

require_relative 'command_templates/generate_command_template'
require_relative '../../../services/script_generator/script_generator'
require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class Base < Templates::GenerateCommandTemplate
        AlcesJob::CLI.register 'generate universal', self
        desc 'Creates a universal sbatch script'

        option :nodes, type: :integer, aliases: ['-N'],
                       desc: 'Requests the number of compute nodes for the job'

        option :ntasks, type: :integer, aliases: ['-n'],
                        desc: 'Specifies the total number of tasks for the job'

        option :cpus_per_task, type: :integer, aliases: ['-c'],
                               desc: 'Specifies CPU cores per task'
        option :gres, type: :string,
                      desc: 'Specifies generic resources such as GPUs or MICs'

        option :array, type: :string,
                       desc: 'Sets a Slurm array specification for multiple jobs'

        option :dependency, type: :string,
                            desc: 'Sets a Slurm dependency string for the job'

        def call(**options)
          paths = Services::Paths.new
          pastel = Pastel.new

          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          begin
            if options[:site_config]
              admin_path = paths.admin_config_path
              if File.exist?(admin_path)
                spinner.update(title: 'Loading admin config')
                spinner.auto_spin
                admin = YAML.load_file(admin_path)
                admin_keys = admin.keys
                puts
                options.each_key do |key|
                  puts pastel.yellow("You are overwriting the system admin defined #{key}") if admin_keys.include?(key)
                end

                options = admin.merge(options)
                spinner.success('(loaded)')
              end
            end
          rescue StandardError => e
            spinner.error('(failed to load)')
            puts pastel.red("\nAn error occurred while accessing the admin config\n")
            warn e.message
            exit(1)
          end

          begin
            unless options[:profile].nil?
              profile_path = paths.user_profile_path(options[:profile].strip)
              options.delete(:profile)
              if File.exist?(profile_path)
                spinner.update(title: 'loading profile')
                spinner.auto_spin
                profile = YAML.load_file(profile_path)
                options_keys = options.keys
                puts
                profile.each_key do |key|
                  if options_keys.include?(key)
                    puts pastel.yellow("Ignoring profile flag #{key}")
                  else
                    puts pastel.green("Loaded profile flag #{key}")
                  end
                end

                options = profile.merge(options)
                spinner.success('(loaded profile)')
              else
                puts pastel.red("\nA profile with that name was not found\n")
              end
            end
          rescue StandardError => e
            spinner.error('(failed to load)')
            puts pastel.red("\nAn error occurred while accessing the specified profile\n")
            warn e.message
            exit(1)
          end

          # Generate sbatch file bases on user inputs
          puts
          spinner.update(title: 'generating SBATCH script')
          spinner.auto_spin

          generator = Services::ScriptGenerator.new(options)
          script_contents = generator.generate

          if options[:dry_run]
            spinner.success(pastel.green('(successful)'))
            puts pastel.green("\nThe SBTACH script has been generated and looks as follows:")
            puts script_contents
            exit(0)
          end

          begin
            if File.exist?(generator.file_path)
              spinner.error(pastel.red('(file exists)'))
              exit(0) unless TTY::Prompt.new.yes?("\nAn sbatch already exists do you want to overwrite it?", default: false)
              puts
              spinner.update(title: 'Overwriting SBATCH script')
              spinner.auto_spin
            end
          rescue StandardError => e
            spinner.error('(failed to overwrite)')
            puts pastel.red("\nFailed to check if a script already exits with that name\n")
            warn e.message
            exit(1)
          end

          begin
            script_path = generator.save(script_contents)
          rescue StandardError => e
            spinner.error('(failed to save)')
            puts pastel.red("\nAn error occurred while saving the script\n")
            warn e.message
            exit(1)
          end

          spinner.success(pastel.green('(successful)'))

          puts pastel.green("\nThe SBTACH script has been generated and saved to #{script_path}\n")

          # Submit the sbatch file to sbatch if user adds submit flag
          exit(0) unless options[:submit]

          unless options[:yes] || TTY::Prompt.new.yes?("\nWould you like to submit this script?", default: false)
            puts pastel.yellow("\nSkipping submission\n")
            exit(0)
          end

          spinner.update(title: 'submitting script')
          spinner.auto_spin

          begin
            stdout, status = generator.submit(script_path)
          rescue StandardError => e
            spinner.error(pastel.red('(failed to submit)'))
            puts pastel.red("\nAn error occurred while submitting to sbatch\n")
            warn e.message
            exit(1)
          end

          unless status.success?
            spinner.error(pastel.red('(error)'))
            puts pastel.red("\nAn error occurred\n")
            exit(1)
          end

          spinner.success('(submitted)')

          puts "\n#{stdout}\n"
          exit(0)
        rescue StandardError => e
          spinner.error('(command error)')
          puts pastel.red("\nAn error occurred while running the command\n")
          warn e.message
          exit(1)
        end
      end
    end
  end
end
