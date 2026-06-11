# frozen_string_literal: true

require 'tty-prompt'
require 'terminal-table'
require 'pastel'
require 'yaml'
require 'erb'

module AlcesJob
  module Services
    class InteractiveWizard
      def system_info
        @info = YAML.load_file(File.expand_path('../../../config.yaml', __dir__))['admin_config_file']
      end

      def valid_slurm_time?(time_string, max_time = '7-00:00:00')
        return false if time_string.nil?
        return false if time_string.strip.empty?

        match = time_string.match(/^(\d+)-(\d{2}):(\d{2}):(\d{2})$/)

        return false unless match

        return false unless match

        days = match[1].to_i
        hours = match[2].to_i
        minutes = match[3].to_i
        seconds = match[4].to_i

        return false if hours > 23
        return false if minutes > 59
        return false if seconds > 59

        total_seconds =
          (days * 86_400) +
          (hours * 3600) +
          (minutes * 60) +
          seconds

        max_seconds = slurm_time_to_seconds(max_time)

        return true if max_seconds.zero?

        total_seconds <= max_seconds
      end

      def human_readable_time(max_time)
        days, time = max_time.split('-')
        hours, minutes, seconds = time.split(':')

        parts = []

        parts << "#{days.to_i} days" if days.to_i.positive?
        parts << "#{hours.to_i} hours" if hours.to_i.positive?
        parts << "#{minutes.to_i} minutes" if minutes.to_i.positive?
        parts << "#{seconds.to_i} seconds" if seconds.to_i.positive?

        parts.join(', ')
      end

      def slurm_time_to_seconds(time_string)
        days, time = time_string.split('-')
        hours, minutes, seconds = time.split(':')

        (days.to_i * 86_400) +
          (hours.to_i * 3600) +
          (minutes.to_i * 60) +
          seconds.to_i
      end

      def normalize_slurm_time(time_value)
        if time_value.is_a?(Integer)
          days = time_value / 86_400
          remainder = time_value % 86_400

          hours = remainder / 3600
          remainder %= 3600

          minutes = remainder / 60
          seconds = remainder % 60

          return format(
            '%<days>d-%<hours>02d:%<minutes>02d:%<seconds>02d', days: days, hours: hours, minutes: minutes, seconds: seconds
          )
        end

        time_string = time_value.to_s

        return time_string if time_string.match?(/^\d+-\d{2}:\d{2}:\d{2}$/)

        return "0-#{time_string}" if time_string.match?(/^\d{2}:\d{2}:\d{2}$/)

        time_string
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def call
        system_info

        puts 'Welcome to the interactive mode!'

        rows = [
          ['serial', 'Single-node CPU job'],
          ['mpi',    'Distributed job using MPI across nodes'],
          ['gpu',    'GPU-accelerated workload'],
          ['array',  'Many similar jobs run as a job array']
        ]

        table = Terminal::Table.new do |t|
          t.title = 'Available Job Types'
          t.headings = %w[Type Description]
          t.rows = rows
        end

        puts table

        partition_types = @info[:partitions]

        max_run_time = nil

        partition_list = []

        puts partition_types

        partition_types.each do |partition|
          partition_list.append(partition[:partition])

          partition[:time_limit] = normalize_slurm_time(partition[:time_limit]) if partition[:time_limit].is_a?(Integer)
        end

        nodes = @info[:nodes]

        max_memory = 0
        max_cpu_cores = 0

        nodes.each do |node|
          max_memory = node[:memory] if node[:memory] > max_memory
          max_cpu_cores = node[:cpus] if node[:cpus] > max_cpu_cores
        end

        human_readable_max_time = nil

        prompt = TTY::Prompt.new

        puts partition_types

        types_of_job = ['serial (default)', 'mpi', 'gpu', 'array']

        job_type = prompt.select('What type of job would you like to run?', types_of_job)

        # To add in later?  nodes: 'How many nodes would you like to request?',
        # array: 'What array range would you like to use (e.g. 1-100)?',
        # max_concurrent_tasks: 'What is the maximum number of array tasks that may run simultaneously?',
        # gres: 'How many GPUs would you like to request?',
        # ntasks: 'How many MPI tasks would you like per node?',

        question_bank = {
          serial: {
            job_name: 'What is your job name?',
            partition: 'Which partition would you like to use?',
            time: 'How long would you like your job to run for?',
            cpus_per_task: 'How many CPU cores would you like to request?',
            mem: 'How much memory will your job use? (MB)',
            command: 'What command would you like to run?'
          },

          mpi: {
            job_name: 'What is your job name?',
            partition: 'Which partition would you like to use?',
            time: 'How long would you like your job to run for?',
            cpus_per_task: 'How many CPU cores would each MPI task require?',
            mem: 'How much memory will your job use? (MB)',
            command: 'What MPI command would you like to run?'
          },

          gpu: {
            job_name: 'What is your job name?',
            partition: 'Which partition would you like to use?',
            time: 'How long would you like your job to run for?',
            cpus_per_task: 'How many CPU cores would you like to request?',
            mem: 'How much memory will your job use? (MB)',
            command: 'What command would you like to run?'
          },

          array: {
            job_name: 'What is your job name?',
            partition: 'Which partition would you like to use?',
            time: 'How long would you like your job to run for?',

            mem: 'How much memory would you like per array task? (MB)',
            command: 'What command would you like to run?'
          }
        }

        defaults = {
          job_name: 'my_slurm_job',
          time: '00-01:00:00',
          cpus_per_task: '1',
          mem: '1024',
          command: '#YOUR_COMMAND_HERE'
        }

        job_type = job_type.split[0] if job_type.split.length > 1

        selected_partition = nil

        system('clear')
        wizard = self

        questions = question_bank[job_type.to_sym]

        result = prompt.collect do # rubocop:disable Metrics/BlockLength
          questions.each do |item, question| # rubocop:disable Metrics/BlockLength
            case item
            when :partition

              partition_rows = partition_types.map do |partition|
                [
                  partition[:partition],
                  partition[:time_limit],
                  wizard.human_readable_time(partition[:time_limit]),
                  partition[:default] ? 'True' : 'False'
                ]
              end

              puts Terminal::Table.new(
                title: 'Available Partitions',
                headings: ['Partition', 'Time Limit', 'Readable', 'Default'],
                rows: partition_rows
              )

              selected_partition = key(item).select(question, partition_list)

            when :time
              selected_partition_info = partition_types.find do |partition|
                partition[:partition] == selected_partition
              end

              max_run_time = selected_partition_info[:time_limit]
              human_readable_max_time = wizard.human_readable_time(max_run_time)

              puts "The max runtime for #{selected_partition} is #{max_run_time}, i.e. #{human_readable_max_time}"

              key(item).ask(question, default: defaults[item]) do |q|
                q.validate do |input|
                  wizard.valid_slurm_time?(input, max_run_time)
                end

                q.messages[:valid?] =
                  "Time must be in format D-HH:MM:SS and not exceed #{human_readable_max_time}"
              end

            when :mem
              puts "Max memory: #{max_memory} MB"
              key(item).ask(question, default: defaults[item]) do |q|
                q.validate(/\A\d+\z/)
                q.messages[:valid?] = 'Please enter a whole number'
                q.validate do |input|
                  input.to_i <= max_memory
                end

                q.messages[:valid?] = 'Value cannot be greater than maximum memory.'

                q.convert :int
              end

            when :cpus_per_task
              puts "Max cpu cores: #{max_cpu_cores}"

              key(item).ask(question, default: defaults[item]) do |q|
                q.validate(/\A\d+\z/)
                q.messages[:valid?] = 'Please enter a whole number'
                q.validate do |input|
                  input.to_i <= max_cpu_cores
                end

                q.messages[:valid?] = 'Value cannot be greater than maximum cpu cores.'
                q.convert :int
              end

            when :command
              puts 'Examples: python script.py, Rscript analysis.R, ./my_program, mpirun ./my_program'
              key(item).ask(question, default: defaults[item])

            when :job_name
              key(item).ask(question, default: defaults[item])

            else
              key(item).ask(question)
            end
            system('clear')
          end
        end

        loop do # rubocop:disable Metrics/BlockLength
          job_type = 'default' if job_type == 'serial'

          generator = AlcesJob::Services::Generator.new(
            result.merge(template: job_type)
          )

          script = generator.generate

          puts script

          break unless prompt.yes?('Would you like to edit any of your inputs?')

          field = prompt.select(
            'Which input would you like to edit?',
            result.keys
          )

          system('clear')

          case field
          when :partition
            partition_rows = partition_types.map do |partition|
              [
                partition[:partition],
                partition[:time_limit],
                wizard.human_readable_time(partition[:time_limit])
              ]
            end

            puts Terminal::Table.new(
              title: 'Available Partitions',
              headings: ['Partition', 'Time Limit', 'Readable'],
              rows: partition_rows
            )

            selected_partition = prompt.select(
              questions[:partition],
              partition_list
            )

            result[:partition] = selected_partition

            selected_partition_info = partition_types.find do |partition|
              partition[:partition] == selected_partition
            end

            max_run_time = selected_partition_info[:time_limit]
            human_readable_max_time = wizard.human_readable_time(max_run_time)

            puts "The max runtime for #{selected_partition} is #{max_run_time}, i.e. #{human_readable_max_time}"

            unless wizard.valid_slurm_time?(result[:time], max_run_time)
              puts "Your current time value #{result[:time]} is too high for #{selected_partition}."

              result[:time] = prompt.ask(
                questions[:time],
                default: defaults[:time]
              ) do |q|
                q.validate do |input|
                  wizard.valid_slurm_time?(input, max_run_time)
                end

                q.messages[:valid?] = "Time must be in format D-HH:MM:SS and not exceed #{human_readable_max_time}"
              end
            end

          when :time
            selected_partition_info = partition_types.find do |partition|
              partition[:partition] == result[:partition]
            end

            max_run_time = selected_partition_info[:time_limit]
            human_readable_max_time = wizard.human_readable_time(max_run_time)

            puts "The max runtime for #{result[:partition]} is #{max_run_time}, i.e. #{human_readable_max_time}"

            result[:time] = prompt.ask(
              questions[:time],
              default: result[:time]
            ) do |q|
              q.validate do |input|
                wizard.valid_slurm_time?(input, max_run_time)
              end

              q.messages[:valid?] = "Time must be in format D-HH:MM:SS and not exceed #{human_readable_max_time}"
            end

          when :mem
            puts "Max memory: #{max_memory} MB"

            result[:mem] = prompt.ask(
              questions[:mem],
              default: result[:mem].to_s
            ) do |q|
              q.validate do |input|
                input.match?(/\A\d+\z/) &&
                  input.to_i >= 1 &&
                  input.to_i <= max_memory
              end

              q.messages[:valid?] = "Please enter a whole number between 1 and #{max_memory} MB"

              q.convert :int
            end

          when :cpus_per_task
            puts "Max cpu cores: #{max_cpu_cores}"

            result[:cpus_per_task] = prompt.ask(
              questions[:cpus_per_task],
              default: result[:cpus_per_task].to_s
            ) do |q|
              q.validate do |input|
                input.match?(/\A\d+\z/) &&
                  input.to_i >= 1 &&
                  input.to_i <= max_cpu_cores
              end

              q.messages[:valid?] = "Please enter a whole number between 1 and #{max_cpu_cores}"

              q.convert :int
            end

          when :command
            puts 'Examples: python script.py, Rscript analysis.R, ./my_program, mpirun ./my_program'

            result[:command] = prompt.ask(
              questions[:command],
              default: result[:command]
            )

          when :job_name
            result[:job_name] = prompt.ask(
              questions[:job_name],
              default: result[:job_name]
            )

          else
            result[field] = prompt.ask(
              "Enter new value for #{field}:",
              default: result[field].to_s
            )
          end

          system('clear')
        end

        job_type = 'default' if job_type == 'serial'

        generator = AlcesJob::Services::Generator.new(
          result.merge(template: job_type)
        )

        exit(0) unless prompt.yes?('Write script to file?')

        file_path = generator.save

        puts "Script has been saved to #{file_path}"

        exit(0) unless prompt.yes?('Would you like to submit the job to SBATCH?', default: false)

        stdout, status = generator.submit(file_path)

        unless status.success?
          puts 'An error occurred'
          exit(1)
        end

        puts stdout
        exit(0)
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  end
end
