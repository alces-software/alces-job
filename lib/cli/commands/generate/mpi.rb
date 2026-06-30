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
      class MPI < Templates::GenerateCommandTemplate
        AlcesJob::CLI.register 'generate mpi', self
        desc 'Create a Slurm MPI job script'

        option :nodes, type: :integer, aliases: ['-N'], desc: 'Number of compute nodes'
        option :ntasks, type: :integer, aliases: ['-n'], desc: 'Number of MPI tasks'
        option :cpus_per_task, type: :integer, aliases: ['-c'], desc: 'CPU cores per task'

        def call(**options)
          options[:module] = AlcesJob::Services.module_extractor(ARGV)
          prompt = TTY::Prompt.new
          pastel = Pastel.new

          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          # ------------------------------------------------------------
          # Load config
          # ------------------------------------------------------------
          begin
            if options[:site_config]
              spinner.update(title: 'loading configuration')
              spinner.auto_spin

              config_manager = Services::ConfigManager.new(options)
              options = config_manager.config

              spinner.success(pastel.green('(Loaded)'))

              config_manager.output.each { |line| puts line }
            end
          rescue Errno::EACCES
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red("\nCannot read configuration file due to insufficient permissions.\n")
          rescue StandardError => e
            spinner.error(pastel.red('(Failed)'))
            warn pastel.red("\nFailed to load configuration.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Load profile
          # ------------------------------------------------------------
          begin
            unless options[:profile].nil?
              puts
              spinner.update(title: 'loading profile')
              spinner.auto_spin

              profile_manager = Services::ProfileManager.new(options[:profile], options)
              options = profile_manager.profile
              options.delete(:profile)

              spinner.success(pastel.green('(Loaded)'))

              profile_manager.output.each { |line| puts line }
            end
          rescue Errno::ENOENT, Errno::ENOTDIR
            spinner.error(pastel.red('(Not found)'))
            warn pastel.yellow("\nNo profile was found with the specified name.\n")
          rescue Errno::EACCES, Errno::EROFS
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red("\nYou do not have permission to read the requested profile.\n")
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Failed)'))
            warn pastel.red("\nFailed to load profile.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Generate script
          # ------------------------------------------------------------
          puts
          spinner.update(title: 'generating SBATCH script')
          spinner.auto_spin

          options[:template] = 'mpi'
          if options[:track]
            spec = Gem.loaded_specs['alces-job']
            if spec
              lib_path = File.join(spec.full_gem_path, 'lib/helper_functions/functions.bash')
              job_path = Services::Paths.new.user_job_dir
              options[:tracking_path] = lib_path
              options[:job_path] = job_path
            end
          end

          generator = Services::ScriptGenerator.new(options)
          script = generator.generate

          # ------------------------------------------------------------
          # Dry run
          # ------------------------------------------------------------
          if options[:dry_run]
            spinner.success(pastel.green('(Generated)'))

            box_width = script.lines.map { |line| line.chomp.length }.max + 4
            puts

            puts TTY::Box.frame(
              script,
              title: {
                top_center: pastel.bold.green(' SBATCH Script Preview ')
              },
              padding: 1,
              border: :thick,
              width: box_width
            )
          end

          # ------------------------------------------------------------
          # Overwrite check
          # ------------------------------------------------------------
          begin
            if File.exist?(generator.file_path)
              spinner.error(pastel.red('(File exists)'))

              unless prompt.yes?("\nA SBATCH script already exists at #{generator.file_path}. Overwrite it?", default: false)
                puts pastel.yellow("\nOperation cancelled.\n")
                exit(0)
              end

              puts
              spinner.update(title: 'overwriting script')
              spinner.auto_spin
            end
          rescue Errno::EACCES
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red("\nCannot access output location due to permissions.\n")
            exit(1)
          rescue Errno::ENOTDIR
            spinner.error(pastel.red('(Invalid path)'))
            warn pastel.red("\nThe output path is invalid or does not exist.\n")
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Check failed)'))
            warn pastel.red("\nFailed to check existing script.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Validate before saving
          # ------------------------------------------------------------
          begin
            Tempfile.create(['generated_script', '.slurm']) do |tempfile|
              tempfile.write(script)
              tempfile.flush

              validator = Services::SlurmScriptValidator.new(tempfile.path)

              unless validator.validate?
                spinner.error(pastel.red('(Invalid script)'))

                warn pastel.red("\nThe generated SBATCH script is not valid and was not saved.\n")

                validator.errors.each do |error|
                  warn pastel.red("Error: #{error}")
                end

                validator.warnings.each do |warning|
                  warn pastel.yellow("Warning: #{warning}")
                end

                exit(1)
              end
            end
          rescue Errno::ENOSPC
            spinner.error(pastel.red('(Disk full)'))
            warn pastel.red("\nCannot validate script: temporary filesystem is full.\n")
            exit(1)
          rescue Errno::EACCES, Errno::EROFS
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red("\nCannot create temporary validation file due to permissions or read-only filesystem.\n")
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to validate)'))
            warn pastel.red('Failed to validate script before saving.')
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Save script
          # ------------------------------------------------------------
          begin
            script_path = generator.save(script)
          rescue Errno::ENOSPC
            spinner.error(pastel.red('(Disk full)'))
            warn pastel.red("\nCannot save script: disk is full.\n")
            exit(1)
          rescue Errno::ENOENT, Errno::ENOTDIR
            spinner.error(pastel.red('(Invalid path)'))
            warn pastel.red("\nCannot save script: output path is invalid or missing.\n")
            exit(1)
          rescue Errno::EACCES, Errno::EROFS
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red("\nCannot save script due to permissions or read-only filesystem.\n")
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Save failed)'))
            warn pastel.red("\nFailed to save SBATCH script.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Complete)'))

          puts pastel.green("\nSBATCH script created successfully:\n#{script_path}\n")

          # ------------------------------------------------------------
          # Submit job
          # ------------------------------------------------------------
          exit(0) unless options[:submit]

          unless options[:yes] || prompt.yes?('Submit this job to Slurm?', default: false)
            puts pastel.yellow("\nSubmission skipped.\n")
            exit(0)
          end

          spinner.update(title: 'submitting job')
          spinner.auto_spin

          begin
            stdout, status = generator.submit(script_path)
          rescue StandardError => e
            spinner.error(pastel.red('(Submission failed)'))
            warn pastel.red("\nFailed to submit job:")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          unless status.success?
            spinner.error(pastel.red('(Error)'))
            warn pastel.red("\nSlurm rejected the job submission.")
            warn pastel.red("#{stdout}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Submitted)'))

          puts "\n#{stdout}\n"
          exit(0)

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          spinner.error(pastel.red('(Unexpected error)'))
          warn pastel.red("\nAn unexpected error occurred while generating the script.")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
