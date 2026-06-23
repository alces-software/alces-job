# frozen_string_literal: true

require 'tty-prompt'
require 'terminal-table'
require 'pastel'
require 'erb'

require_relative 'sys_info/sys_info'
require_relative 'paths/paths'
require_relative 'converters/time_converter'
require_relative 'converters/memory_converter'

module AlcesJob
  module Services
    class InteractiveWizard
      def initialize
        @info = AlcesJob::Services::SysInfo.load_info(Services::Paths.new.system_info_path)
        @info = deep_symbolize_keys(@info)

        return unless @info[:nodes].empty? &&
                      @info[:partitions].empty? &&
                      @info[:packages].empty? &&
                      @info[:gpu_total].zero?

        @info = prompt_for_system_info
      end

      def call
        pastel = Pastel.new

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

          partition[:time_limit] = TimeConverter.normalise_slurm_time(partition[:time_limit]) if partition[:time_limit].is_a?(Integer)
        end

        nodes = Array(@info[:nodes])
        nodes = prompt_for_nodes(prompt) if nodes.empty?

        max_memory = 0
        max_cpu_cores = 0

        nodes.each do |node|
          node_memory = MemoryConverter.to_mb((node[:memory] || node['memory']).to_s)
          node_cpus = (node[:cpus] || node['cpus']).to_i

          max_memory = node_memory if node_memory && node_memory > max_memory
          max_cpu_cores = node_cpus if node_cpus > max_cpu_cores
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

        questions = question_bank[job_type.to_sym]

        result = prompt.collect do
          questions.each do |item, question|
            case item
            when :partition

              partition_rows = partition_types.map do |partition|
                [
                  partition[:partition],
                  partition[:time_limit],
                  TimeConverter.to_human_readable(partition[:time_limit]),
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
              human_readable_max_time = TimeConverter.to_human_readable(max_run_time)

              puts "The max runtime for #{selected_partition} is #{max_run_time}, i.e. #{human_readable_max_time}"

              key(item).ask(question, default: defaults[item]) do |q|
                q.validate do |input|
                  TimeConverter.valid_slurm_time?(input, max_run_time)
                end

                q.messages[:valid?] =
                  "Time must be in format D-HH:MM:SS and not exceed #{human_readable_max_time}"
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
          job_type = 'universal' if job_type == 'serial'

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
                TimeConverter.to_human_readable(partition[:time_limit])
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
            human_readable_max_time = TimeConverter.to_human_readable(max_run_time)

            puts "The max runtime for #{selected_partition} is #{max_run_time}, i.e. #{human_readable_max_time}"

            unless TimeConverter.valid_slurm_time?(result[:time], max_run_time)
              puts "Your current time value #{result[:time]} is too high for #{selected_partition}."

              result[:time] = prompt.ask(
                questions[:time],
                default: defaults[:time]
              ) do |q|
                q.validate do |input|
                  TimeConverter.valid_slurm_time?(input, max_run_time)
                end

                q.messages[:valid?] = "Time must be in format D-HH:MM:SS and not exceed #{human_readable_max_time}"
              end
            end

          when :time
            selected_partition_info = partition_types.find do |partition|
              partition[:partition] == result[:partition]
            end

            max_run_time = selected_partition_info[:time_limit]
            human_readable_max_time = TimeConverter.to_human_readable(max_run_time)

            puts "The max runtime for #{result[:partition]} is #{max_run_time}, i.e. #{human_readable_max_time}"

            result[:time] = prompt.ask(
              questions[:time],
              default: result[:time]
            ) do |q|
              q.validate do |input|
                TimeConverter.valid_slurm_time?(input, max_run_time)
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

        job_type = 'universal' if job_type == 'serial'

        generator = AlcesJob::Services::ScriptGenerator.new(
          result.merge(template: job_type)
        )

        exit(0) unless prompt.yes?('Write script to file?')

        exit(0) if File.exist?(generator.file_path) && !prompt.yes?("\nAn sbatch already exists do you want to overwrite it?", default: false)

        file_path = generator.save(generator.generate)

        puts "Script has been saved to #{file_path}"

        exit(0) unless prompt.yes?('Would you like to submit the job to SBATCH?', default: false)

        stdout, status = generator.submit(file_path)

        unless status.success?
          puts pastel.red("\nAn error occurred\n")
          exit(1)
        end

        puts "\n#{stdout}\n"
        exit(0)
      end

      private

      def deep_symbolize_keys(value)
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

        puts Pastel.new.red("\nUnable to detect a Slurm environment. Please enter fallback cluster configuration for the system you wish to run the script on\n")

        {
          nodes: prompt_for_nodes(prompt),
          partitions: prompt_for_partitions(prompt),
          packages: [],
          gpu_total: prompt.ask('How many GPUs are available in total?', default: '0') do |q|
            q.validate(/\A\d+\z/)
            q.messages[:valid?] = 'Please enter a whole number.'
            q.convert :int
          end
        }
      end

      def prompt_for_partitions(prompt)
        partition_input = prompt.ask('Partition names (comma-separated)', default: 'default') do |q|
          q.required true
        end

        partition_names = partition_input.split(',').map(&:strip).reject(&:empty?)
        partition_names = ['default'] if partition_names.empty?

        partition_names.map.with_index do |name, index|
          {
            partition: name,
            time_limit: prompt.ask("Max time for partition #{name}", default: '0-07:00:00') do |q|
              q.validate { |input| !TimeConverter.to_seconds(input).nil? }
              q.messages[:valid?] = 'time must be in format HH:MM:SS or D-HH:MM:SS'
            end,
            default: index.zero?
          }
        end
      end

      def prompt_for_nodes(prompt)
        [{
          node: 'local',
          cpus: prompt.ask('Maximum CPU cores per node', default: '4') do |q|
            q.validate(/\A\d+\z/)
            q.messages[:valid?] = 'Please enter a whole number.'
            q.convert :int
          end,
          memory: prompt.ask('Maximum memory per node (MB)', default: '5000') do |q|
            q.validate do |input|
              !MemoryConverter.to_mb(input).nil?
            end
            q.messages[:valid?] = 'Please enter memory using M, MB, G, GB e.g. 5000M or 4G'
            q.convert do |input|
              MemoryConverter.to_mb(input)
            end
          end
        }]
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  end
end
