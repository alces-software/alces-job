# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'
require 'yaml'
require 'tempfile'
require 'fileutils'
require 'shellwords'
require 'English'
require 'diffy'

require_relative 'command_templates/generate_command_template'

require_relative '../../../services/validators/slurm_script_validator'
require_relative '../../../services/script_generator/script_generator'
require_relative '../../../services/module_extractor/module_extractor'
require_relative '../../../services/config_manager/config_manager'
require_relative '../../../services/profile_manager/profile_manager'
require_relative '../../../services/paths/paths'
require_relative '../../../services/editor/edit'
require_relative '../../../services/tracking/tracking_methods'

module AlcesJob
  module CLI
    module Commands
      class Base < Templates::GenerateCommandTemplate
        AlcesJob::CLI.register 'generate universal', self
        desc 'Create a Slurm job script (universal template)'

        option :nodes, type: :integer, aliases: ['-N'], desc: 'Number of compute nodes'
        option :ntasks, type: :integer, aliases: ['-n'], desc: 'Number of tasks'
        option :cpus_per_task, type: :integer, aliases: ['-c'], desc: 'CPU cores per task'
        option :gres, type: :string, desc: 'Generic resources (e.g. GPUs)'
        option :array, type: :string, desc: 'Slurm array specification'
        option :dependency, type: :string, desc: 'Job dependency string'
        option :template, type: :string, desc: 'The template you want to use'

        def call(**options)
          options[:modules] = AlcesJob::Services.module_extractor(ARGV)

          pastel = Pastel.new
          prompt = TTY::Prompt.new

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
              # puts
              # puts options['values']

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

          if !options[:modules].nil? && !options[:modules].empty?
            packages_info = Services::SysInfo.load_info[:packages]

            deprecated_module = false
            output = []
            packages_info.to_h.each_value do |package_group|
              package_group.each do |package|
                next unless options[:modules].include?(package[:full_name]) && package[:deprecated]

                deprecated_module = true
                output << pastel.yellow("#{package[:full_name]} is deprecated")
              end
            end

            if deprecated_module
              spinner.error('(Deprecated module)')

              puts
              output.each do |line|
                puts line
              end

              return unless prompt.yes?("\none or more of your packages is deprecated do you want to continue?")
            end

            return if deprecated_module && !spinner.auto_spin
          end

          Services::Tracking.inject_tracking(options)

          generator = Services::ScriptGenerator.new(options)
          script = generator.generate

          spinner.success(pastel.green('(Generated)'))

          if options[:edit]
            edited_script = AlcesJob::Services::Editor.edit_script_with_preview(
              script,
              prompt: prompt,
              pastel: pastel,
              validator_class: Services::SlurmScriptValidator,
              editor: options[:editor]
            )

            case edited_script[:status]
            when :saved
              script = edited_script[:script]
            when :cancelled
              puts pastel.yellow("\nEdited changes discarded.\n")
              exit(0)
            when :invalid
              spinner.error(pastel.red('(Invalid script)'))
              exit(1)
            end

            if options[:output_file].nil?
              job_name = AlcesJob::Services::Editor.edited_job_name(script)
              generator = Services::ScriptGenerator.new(options.merge(job_name: job_name)) if job_name
            end
          end

          # ------------------------------------------------------------
          # Dry run
          # ------------------------------------------------------------
          if options[:dry_run]

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

            exit(0)
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
            puts
            spinner.update(title: 'validating SBATCH script')
            spinner.auto_spin
            Tempfile.create(['generated_script', '.slurm']) do |tempfile|
              tempfile.write(script)
              tempfile.flush

              validator = Services::SlurmScriptValidator.new(tempfile.path)

              unless validator.validate?
                spinner.error(pastel.red('(Invalid script)'))
                warn pastel.red("\nThe generated SBATCH script is not valid and was not saved.\n")
                puts unless validator.errors.empty?
                validator.errors.each do |error|
                  warn pastel.red("Error: #{error}")
                end
              end

              puts unless validator.warnings.empty? && validator.errors.empty?
              validator.warnings.each do |warning|
                warn pastel.yellow("Warning: #{warning}")
              end

              exit(1) unless validator.validate?
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
            warn pastel.red("\nFailed to submit job.")
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
