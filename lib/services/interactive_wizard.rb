# frozen_string_literal: true

require 'tty-prompt'
require 'terminal-table'
require 'pastel'
require 'yaml'
require 'erb'

require_relative 'sys_info/sys_info'
require_relative 'converters/time_converter'
require_relative 'converters/memory_converter'

module AlcesJob
  module Services
    class InteractiveWizard
      def system_info
        config_path = File.expand_path('../../config/config.yaml', __dir__)

        config = YAML.safe_load_file(config_path, symbolize_names: true)

        @info = AlcesJob::Services::SysInfo.load_info(config[:system_info_file])
        @info = self.class.deep_symbolize_keys(@info)

        return unless @info[:nodes].empty? &&
                      @info[:partitions].empty? &&
                      @info[:packages].empty? &&
                      @info[:gpu_total].zero?

        @info = prompt_for_system_info
      end

      def self.deep_symbolize_keys(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, val), result|
            result[key.to_sym] = deep_symbolize_keys(val)
          end
        when Array
          value.map { |item| deep_symbolize_keys(item) }
        else
          value
        end
      end

      def prompt_for_system_info
        prompt = TTY::Prompt.new

        puts 'Unable to detect a Slurm environment. Please enter fallback cluster configuration for the system you wish to run the script on.'

        partitions = prompt_for_partitions(prompt)
        nodes = prompt_for_nodes(prompt)

        gpu_total = prompt.ask('How many GPUs are available in total?', default: '0') do |q|
          q.validate(/\A\d+\z/)
          q.messages[:valid?] = 'Please enter a whole number.'
          q.convert :int
        end

        {
          nodes: nodes,
          partitions: partitions,
          packages: [],
          gpu_total: gpu_total
        }
      end

      def prompt_for_partitions(prompt)
        partition_input = prompt.ask('Partition names (comma-separated)', default: 'default') do |q|
          q.required true
        end

        partition_names = partition_input.split(',').map(&:strip).reject(&:empty?)
        partition_names = ['default'] if partition_names.empty?

        partition_names.map.with_index do |name, index|
          time_limit = prompt.ask("Max time for partition #{name}", default: '0-07:00:00') do |q|
            q.validate { |input| !TimeConverter.to_seconds(input).nil? }
            q.messages[:valid?] = 'time must be in format HH:MM:SS or D-HH:MM:SS'
          end

          {
            partition: name,
            time_limit: time_limit,
            default: index.zero?
          }
        end
      end

      def prompt_for_nodes(prompt)
        max_cpu_cores = prompt.ask('Maximum CPU cores per node', default: '4') do |q|
          q.validate(/\A\d+\z/)
          q.messages[:valid?] = 'Please enter a whole number.'
          q.convert :int
        end

        max_memory = prompt.ask('Maximum memory per node (MB)', default: '5000') do |q|
          q.validate do |input|
            !MemoryConverter.to_mb(input).nil?
          end
          q.messages[:valid?] = 'Please enter memory using M, MB, G, GB e.g. 5000M or 4G'
          q.convert do |input|
            MemoryConverter.to_mb(input)
          end
        end

        [{ node: 'local', cpus: max_cpu_cores, memory: max_memory }]
      end

      def slurm_time_to_seconds(time)
        return nil if time.nil?

        time = time.strip
        return nil if time.empty?

        days = 0

        if time.include?('-')
          day_part, time_part = time.split('-', 2)

          return nil unless day_part.match?(/\A\d+\z/)

          days = day_part.to_i
        else
          time_part = time
        end
        parts = time_part.split(':')

        return nil unless parts.length == 3
        return nil unless parts.all? { |part| part.match?(/\A\d+\z/) }

        hours, minutes, seconds = parts.map(&:to_i)

        return nil unless hours.between?(0, 23)
        return nil unless minutes.between?(0, 59)
        return nil unless seconds.between?(0, 59)

        (days * 86_400) + (hours * 3_600) + (minutes * 60) + seconds
      end

      def valid_slurm_time?(input, max_time)
        input_seconds = slurm_time_to_seconds(input)
        max_seconds = slurm_time_to_seconds(max_time)

        return false if input_seconds.nil?
        return false if max_seconds.nil?

        input_seconds.positive? && input_seconds <= max_seconds
      end

      def human_readable_time(max_time)
        return 'unknown' if max_time.nil?

        max_time = max_time.strip

        days = 0

        if max_time.include?('-')
          day_part, time_part = max_time.split('-', 2)
          days = day_part.to_i
        else
          time_part = max_time
        end

        hours, minutes, seconds = time_part.split(':').map(&:to_i)

        parts = []

        parts << "#{days} days" if days.positive?
        parts << "#{hours} hours" if hours.positive?
        parts << "#{minutes} minutes" if minutes.positive?
        parts << "#{seconds} seconds" if seconds.positive?

        parts.empty? ? '0 seconds' : parts.join(', ')
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

        prompt = TTY::Prompt.new

        partition_types = Array(@info[:partitions])
        partition_types = prompt_for_partitions(prompt) if partition_types.empty?

        max_run_time = nil

        partition_list = []

        partition_types.each do |partition|
          partition_list.append(partition[:partition])

          partition[:time_limit] = normalize_slurm_time(partition[:time_limit]) if partition[:time_limit].is_a?(Integer)
        end

        nodes = Array(@info[:nodes])
        nodes = prompt_for_nodes(prompt) if nodes.empty?

        max_memory = 0
        max_cpu_cores = 0

        nodes.each do |node|
          node_memory = MemoryConverter.to_mb((node[:memory] || node['memory']).to_s)
          node_cpus = (node[:cpu] || node['cpus']).to_i

          max_memory = node_memory if node_memory && node_memory > max_memory
          max_cpu_cores = node[:cpus] if node[:cpus] > max_cpu_cores
        end

        human_readable_max_time = nil

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

        result = prompt.collect do
          questions.each do |item, question|
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

              unless selected_partition_info
                puts "Could not find partition information for #{selected_partition}"
                exit(1)
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
                q.validate do |input|
                  !MemoryConverter.to_mb(input).nil?
                end
                q.messages[:valid?] = 'Please enter a whole number'
                q.validate do |input|
                  input.to_i.between?(1, max_memory)
                end

                q.messages[:valid?] = "Please enter a whole number from 1 to #{max_memory} MB"

                q.convert :int
              end

            when :cpus_per_task
              puts "Max cpu cores: #{max_cpu_cores}"

              key(item).ask(question, default: defaults[item]) do |q|
                q.validate(/\A\d+\z/)
                q.messages[:valid?] = 'Please enter a whole number'
                q.validate do |input|
                  input.to_i.between?(1, max_cpu_cores)
                end

                q.messages[:valid?] = "Please enter a whole number between 1 and #{max_cpu_cores}"
                q.convert :int
              end

            when :command
              puts 'Examples: python script.py, Rscript analysis.R, ./my_program, mpirun ./my_program'
              key(item).ask(question, default: defaults[item])

            when :job_name
              key(item).ask(question, default: defaults[item]) do |q|
                q.modify :strip
                q.convert ->(input) { input.gsub(/\s+/, '_') }

                q.validate do |input|
                  cleaned = input.strip.gsub(/\s+/, '_')
                  cleaned.match?(/\A[a-zA-Z0-9_.-]+\z/) && !cleaned.empty?
                end

                q.messages[:valid?] = 'Job name can only contain letters, numbers, underscores, dots, and hyphens.'
              end

            else
              key(item).ask(question)
            end
            system('clear')
          end
        end

        loop do
          job_type = 'default' if job_type == 'serial'

          generator = AlcesJob::Services::ScriptGenerator.new(
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

            key(item).ask(question, default: defaults[item]) do |q|
              q.validate do |input|
                requested_memory_mb = MemoryConverter.to_mb(input)

                !requested_memory_mb.nil? &&
                  requested_memory_mb >= 1 &&
                  requested_memory_mb <= max_memory
              end

              q.messages[:valid?] =
                "Enter memory between 1 MB and #{max_memory} MB, such as 500, 500M, or 2G."

              q.convert do |input|
                MemoryConverter.to_mb(input)
              end
            end

          when :cpus_per_task
            puts "Max cpu cores: #{max_cpu_cores}"

            result[:cpus_per_task] = prompt.ask(
              questions[:cpus_per_task],
              default: result[:cpus_per_task].to_s
            ) do |q|
              q.validate do |input|
                input.match?(/\A\d+\z/) &&
                  input.to_i.between?(1, max_cpu_cores)
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
            ) do |q|
              q.modify :strip
              q.convert ->(input) { input.gsub(/\s+/, '_') }

              q.validate do |input|
                cleaned = input.strip.gsub(/\s+/, '_')
                cleaned.match?(/\A[a-zA-Z0-9_.-]+\z/) && !cleaned.empty?
              end

              q.messages[:valid?] = 'Job name can only contain letters, numbers, underscores, dots, and hyphens.'
            end

          else
            result[field] = prompt.ask(
              "Enter new value for #{field}:",
              default: result[field].to_s
            )
          end

          system('clear')
        end

        job_type = 'default' if job_type == 'serial'

        generator = AlcesJob::Services::ScriptGenerator.new(
          result.merge(template: job_type)
        )

        exit(0) unless prompt.yes?('Write script to file?')

        exit(0) if File.exist?(generator.file_path) && !prompt.yes?("\nAn sbatch already exists do you want to overwrite it?", default: false)

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
