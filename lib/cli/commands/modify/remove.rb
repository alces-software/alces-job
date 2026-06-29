# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'open3'
require 'tty-spinner'
require 'tty-prompt'

require_relative '../../../services/validators/slurm_script_validator'
require_relative '../../../services/module_extractor/module_extractor'

module AlcesJob
  module CLI
    module Commands
      class Remove < Dry::CLI::Command
        AlcesJob::CLI.register 'modify remove', self

        desc 'Remove SBATCH flags from a Slurm script'

        argument :script, required: true, desc: 'The script to modify'

        option :job_name, type: :boolean, default: false, desc: 'Remove job-name'
        option :nodes, type: :boolean, default: false, desc: 'Remove nodes'
        option :ntasks, type: :boolean, default: false, desc: 'Remove ntasks'
        option :cpus_per_task, type: :boolean, default: false, desc: 'Remove cpus-per-task'
        option :mem, type: :boolean, default: false, desc: 'Remove mem'
        option :time, type: :boolean, default: false, desc: 'Remove time'
        option :partition, type: :boolean, default: false, desc: 'Remove partition'
        option :account, type: :boolean, default: false, desc: 'Remove account'
        option :gres, type: :boolean, default: false, desc: 'Remove gres'
        option :output, type: :boolean, default: false, desc: 'Remove output'
        option :error, type: :boolean, default: false, desc: 'Remove error'
        option :mail_user, type: :boolean, default: false, desc: 'Remove mail-user'
        option :mail_type, type: :boolean, default: false, desc: 'Remove mail-type'
        option :array, type: :boolean, default: false, desc: 'Remove array'
        option :dependency, type: :boolean, default: false, desc: 'Remove dependency'

        option :output_file, aliases: ['-o'], type: :string, desc: 'Write to new file instead of overwriting'
        option :submit, type: :boolean, default: false, desc: 'Submit to Slurm after modification'

        def initialize
          @sbatch_options = {
            job_name: 'job-name',
            nodes: 'nodes',
            ntasks: 'ntasks',
            cpus_per_task: 'cpus-per-task',
            mem: 'mem',
            time: 'time',
            partition: 'partition',
            account: 'account',
            gres: 'gres',
            output: 'output',
            error: 'error',
            mail_user: 'mail-user',
            mail_type: 'mail-type',
            array: 'array',
            dependency: 'dependency'
          }.freeze
        end

        def call(script:, **options)
          pastel = Pastel.new
          script = File.expand_path(script, Dir.pwd)

          unless File.exist?(script)
            puts pastel.red("\nScript not found: #{script}\n")
            exit(1)
          end

          old_content = File.read(script)
          lines = old_content.lines(chomp: true)

          # Build set of keys to remove
          remove_keys = options.select { |_, v| v == true }.keys

          edited_script = []

          lines.each do |line|
            if line.start_with?('#!')
              edited_script << line
              next
            end

            if line.start_with?('#SBATCH')
              parts = line.split[1]

              unless parts&.start_with?('--') && parts.include?('=')
                edited_script << line
                next
              end

              name, _value = parts.split('=', 2)
              key = name.sub('--', '').tr('-', '_').to_sym

              next if remove_keys.include?(key)

              edited_script << line
              next
            end

            edited_script << line
          end

          file_path =
            if options[:output_file]
              File.join(Dir.pwd, options[:output_file])
            else
              script
            end

          begin
            File.write(file_path, "#{edited_script.join("\n")}\n")
          rescue Errno::ENOSPC
            puts pastel.red("\nUnable to save the modified script because the disk is full. \n")
            exit(1)
          rescue Errno::ENOENT, Errno::ENOTDIR
            puts pastel.red("\nUnable to save the modified script because the output path is invalid or massing")
            exit(1)
          rescue Errno::EACCES, Errno::EROFS
            puts pastel.red("\nUnable to save the modified script due to permissions or a read-only filesystem.\n")
            exit(1)
          rescue Errno::EISDIR
            puts pastel.red("\nUnable to save the modified script because the output path is a directory, not a file. \n")
            exit(1)
          end
          puts pastel.green("\nSBATCH flags removed successfully.\n")
          puts pastel.green("Written to: #{file_path}\n")

          validator = Services::SlurmScriptValidator.new(file_path)

          if validator.validate?
            if options[:submit]
              stdout, _, status = Open3.capture3("sbatch #{file_path}")
              puts stdout
              puts "Exit status: #{status.exitstatus}"
            end

            puts pastel.green("\nValidation passed.\n")
          else
            File.write(file_path, old_content)
            puts pastel.red("\nInvalid script — changes reverted.\n")

            validator.errors.each do |e|
              puts "#{pastel.red('ERROR:')} #{e}"
            end
          end

          validator.warnings.each do |w|
            puts "#{pastel.yellow('WARNING:')} #{w}"
          end
        rescue StandardError => e
          puts pastel.red("\nFatal error: #{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
