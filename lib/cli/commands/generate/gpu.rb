# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'
require 'yaml'
require 'tempfile'

require_relative '../../../services/validators/slurm_script_validator'
require_relative 'command_templates/generate_command_template'
require_relative '../../../services/script_generator/script_generator'
require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class GPU < Templates::GenerateCommandTemplate
        AlcesJob::CLI.register 'generate gpu', self
        desc 'Creates a GPU sbatch script'

        option :nodes, type: :integer, aliases: ['-N'],
                       desc: 'Requests the number of compute nodes for the job'

        option :ntasks, type: :integer, aliases: ['-n'],
                        desc: 'Specifies the total number of tasks for the CUDA/GPU job'

        option :cpus_per_task, type: :integer, aliases: ['-c'],
                               desc: 'Specifies CPU cores per task'

        option :gres, type: :string,
                      desc: 'Specifies generic resources such as GPUs'

        def call(**options)
          paths = Services::Paths.new
          pastel = Pastel.new

          if options[:site_config]
            admin_path = paths.admin_config_path
            if File.exist?(admin_path)
              admin = YAML.load_file(admin_path)
              admin_keys = admin.keys
              puts
              options.each_key do |key|
                puts pastel.yellow("You are overwriting the system admin defined #{key}") if admin_keys.include?(key)
              end

              options = admin.merge(options)
            end
          end

          unless options[:profile].nil?
            profile_path = paths.user_profile_path(options[:profile].strip)
            options.delete(:profile)
            if File.exist?(profile_path)
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
            else
              puts pastel.red("\nA profile with that name was not found\n")
            end
          end

          # Generate sbatch file bases on user inputs
          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.update(title: 'generating SBATCH script')
          spinner.auto_spin

          options[:template] = 'gpu'

          generator = Services::ScriptGenerator.new(options)
          script = generator.generate

          if options[:dry_run]
            spinner.success(pastel.green('(successful)'))
            puts pastel.green("\nThe SBATCH script has been generated and looks as follows:")
            puts script
            exit(0)
          end

          if File.exist?(generator.file_path)
            spinner.error(pastel.red('(file exists)'))
            exit(0) unless TTY::Prompt.new.yes?("\nAn sbatch already exists do you want to overwrite it?", default: false)
            puts
            spinner.update(title: 'Overwriting SBATCH script')
            spinner.auto_spin
          end

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

          script_path = generator.save(script)

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

          stdout, status = generator.submit(script_path)

          unless status.success?
            spinner.error(pastel.red('(error)'))
            puts pastel.red("\nAn error occurred\n")
            exit(1)
          end

          spinner.success('(submitted)')

          puts "\n#{stdout}\n"
          exit(0)
        rescue Errno::ENOENT
          spinner.error(pastel.red('(error)'))
          puts pastel.red("\nAn error occurred\n")
          exit(1)
        end
      end
    end
  end
end
