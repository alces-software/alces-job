# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'
require 'yaml'
require 'tempfile'

require_relative 'command_templates/generate_command_template'

require_relative '../../../services/validators/slurm_script_validator'
require_relative '../../../services/script_generator/script_generator'
require_relative '../../../services/module_extractor/module_extractor'
require_relative '../../../services/config_manager/config_manager'
require_relative '../../../services/profile_manager/profile_manager'

module AlcesJob
  module CLI
    module Commands
      class Array < Templates::GenerateCommandTemplate
        AlcesJob::CLI.register 'generate array', self
        desc 'Creates an array sbatch script'

        option :nodes, type: :integer, aliases: ['-N'], desc: 'Requests the number of compute nodes for the array job'
        option :array, type: :string, desc: 'Sets the Slurm array task specification for the job'

        def call(**options)
          options[:module] = AlcesJob::Services.module_extractor(ARGV)
          Services::Paths.new
          pastel = Pastel.new

          # Generate sbatch file bases on user inputs
          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          begin
            if options[:site_config]
              spinner.update(title: 'Loading admin config')
              spinner.auto_spin
              config_manager = Services::ConfigManager.new(options)
              options = config_manager.config
              spinner.success('(loaded)')
              config_manager.output.each do |line|
                puts line
              end
            end
          rescue StandardError => e
            spinner.error('(failed to load)')
            puts pastel.red("\nAn error occurred while accessing the admin config:\n#{e.message}\n")
            exit(1)
          end

          begin
            unless options[:profile].nil?
              puts
              spinner.update(title: 'loading profile')
              spinner.auto_spin
              profile_manager = Services::ProfileManager.new(options[:profile], options)
              options = profile_manager.profile
              options.delete(:profile)
              spinner.success('(loaded profile)')
              profile_manager.output.each do |line|
                puts line
              end
            end
          rescue Errno::ENOENT
            spinner.error('(failed to load)')
            puts pastel.yellow("\nA profile with that name doesn't exist\n")
          rescue StandardError => e
            spinner.error('(failed to load)')
            puts pastel.red("\nAn error occurred while accessing the specified profile:\n#{e.message}\n")
            exit(1)
          end

          # Generate sbatch file bases on user inputs
          puts
          spinner.update(title: 'generating SBATCH script')
          spinner.auto_spin

          if options[:array].nil? || options[:array].to_s.strip.empty?
            warn 'Error: --array is required for array jobs'
            exit(1)
          end

          options[:template] = 'array'

          generator = Services::ScriptGenerator.new(options)
          script = generator.generate

          if options[:dry_run]
            spinner.success(pastel.green('(successful)'))
            puts pastel.green("\nThe SBATCH script has been generated and looks as follows:")
            puts script
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
            puts pastel.red("\nFailed to check if a script already exits with that name:\n#{e.message}\n")
            exit(1)
          end

          begin
            Tempfile.create(['generated_script', '.slurm']) do |tempfile|
              tempfile.write(script)
              tempfile.flush

              validator = Services::SlurmScriptValidator.new(tempfile.path)

              unless validator.validate?
                spinner.error(pastel.red('(invalid)'))

                puts pastel.bold.red("\nGenerated script may not be valid:\n")
                validator.errors.each { |error| puts pastel.red("ERROR: #{error}") }
                validator.warnings.each { |warning| puts pastel.yellow("WARNING: #{warning}") }

                puts pastel.yellow("\nScript was not saved.\n")
                exit(1)
              end
            end
          rescue StandardError => e
            puts pastel.red("\nFailed to validate file before saving:\n#{e.message}\n")
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

          puts pastel.green("\nThe SBATCH script has been generated and saved to #{script_path}\n")

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
            puts pastel.red("\nAn error occurred while submitting to sbatch:\n#{e.message}\n")
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
          puts pastel.red("\nAn error occurred while running the command:\n#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
