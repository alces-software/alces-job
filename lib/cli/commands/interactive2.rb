# frozen_string_literal: true

require 'dry/cli'
require 'tty-prompt'
require 'terminal-table'
require 'pastel'
require 'erb'
require 'tty-box'
require 'artii'

require_relative '../../services/sys_info/sys_info'
require_relative '../../services/paths/paths'
require_relative '../../services/converters/time_converter'
require_relative '../../services/converters/memory_converter'
require_relative '../../services/profile_manager/profile_manager'

module AlcesJob
  module CLI
    module Commands
      class Wizard < Dry::CLI::Command
        AlcesJob::CLI.register 'new', self

        desc 'This runs the interactive script builder'

        QUESTION_BANK = {
          serial: {
            job_name: 'What is your job name?',
            partition: 'Which partition would you like to use?',
            time: 'How long would you like your job to run for?',
            cpus_per_task: 'How many CPU cores would you like to request?',
            mem: 'How much memory will your job use? (MB)',
            command: 'What command would you like to run?',
            modules: 'What modules would you like to load?',
            prepare: 'Would you like to prepare this job with a dedicated working directory'
          },

          mpi: {
            job_name: 'What is your job name?',
            partition: 'Which partition would you like to use?',
            nodes: 'How many nodes would you like to request?',
            ntasks: 'How many MPI tasks would you like per node?',
            time: 'How long would you like your job to run for?',
            cpus_per_task: 'How many CPU cores would each MPI task require?',
            mem: 'How much memory will your job use? (MB)',
            command: 'What MPI command would you like to run?',
            modules: 'What modules would you like to load?',
            prepare: 'Would you like to prepare this job with a dedicated working directory'
          },

          gpu: {
            job_name: 'What is your job name?',
            partition: 'Which partition would you like to use?',
            time: 'How long would you like your job to run for?',
            gres: 'How many GPUs would you like to request?',
            cpus_per_task: 'How many CPU cores would you like to request?',
            mem: 'How much memory will your job use? (MB)',
            command: 'What command would you like to run?',
            modules: 'What modules would you like to load?',
            prepare: 'Would you like to prepare this job with a dedicated working directory'
          },

          array: {
            job_name: 'What is your job name?',
            partition: 'Which partition would you like to use?',
            array: 'What array range would you like to use (e.g. 1-100)?',
            time: 'How long would you like your job to run for?',
            cpus_per_task: 'How many CPU cores should each array task use?',
            mem: 'How much memory would you like per array task? (MB)',
            command: 'What command would you like to run?',
            modules: 'What modules would you like to load?',
            prepare: 'Would you like to prepare this job with a dedicated working directory'
          }
        }.freeze

        DEFAULT_VALUES = {
          job_name: 'my_slurm_job',
          time: '00-01:00:00',
          gres: '1',
          cpus_per_task: '1',
          ntasks: '1',
          array: '0-2',
          mem: '1024',
          nodes: '1',
          command: 'echo "Hello, World!"'
        }.freeze

        def call(*)
          pastel = Pastel.new
          artii = Artii::Base.new(font: 'standard')
          prompt = TTY::Prompt.new

          # ------------------------------------------------------------
          # System information
          # ------------------------------------------------------------
          all_info = Services::SysInfo.load_info

          partition_info = if valid_partition_info?(all_info[:partitions])
                             all_info[:partitions]
                           else
                             prompt_for_partition_info
                           end

          package_info = all_info[:packages]
          puts package_info

          # ------------------------------------------------------------
          # Welcome message
          # ------------------------------------------------------------
          puts('clear')
          animated_artii_title("ALCES\nJOB\nINTERACTIVE", artii, pastel)
          puts pastel.bold.cyan("Welcome to the interactive wizard!\n")
          prompt.keypress("[Press #{pastel.bold('enter')} to continue] ")
          system('clear')

          # ------------------------------------------------------------
          # Job type selection
          # ------------------------------------------------------------
          types_of_job = ['serial (default)', 'mpi', 'gpu', 'array']
          puts pastel.underline.bold.cyan("\nInteractive Mode")
          puts "\nWelcome to Alces Job interactive mode."
          puts 'This wizard will help you build a SLURM batch script step by step.'
          puts "\nYou will be asked a few questions about your job, such as:"
          puts '  - what type of job you want to run'
          puts '  - how long the job should run for'
          puts '  - how much CPU and memory it needs'
          puts '  - what command should be executed'
          puts 'Helpful explanations and examples will be shown as you go.'
          puts "\nDo not worry if you are unsure - sensible default values will be provided.\n"
          puts pastel.yellow('Tip: Enlarge your terminal screen for a better experience.')
          puts "\nAt the end, you will be able to preview the generated script before saving it.\n\n"
          key = prompt.keypress('[Press any key to continue, or q to quit]')
          system('clear')
          exit(0) if key == 'q'
          puts pastel.underline.magenta.bold("\nJob Types")
          puts "\nPlease specify what type of job you wish to run."
          puts "\n1) #{pastel.cyan('Serial job')}\n\nChoose this if your program runs normally on one machine and does not need GPUs or multiple parallel tasks.\n\n e.g. python script.py or Rscript analysis.R"
          puts "\n2) #{pastel.yellow('MPI (Message Passing Interface)')}\n\nChoose MPI if your program was written to run in parallel using MPI, or if the documentation tells you to run it with mpirun, mpiexec, or srun."
          puts "\n3) #{pastel.green('GPU (Graphics Processing Unit)')}\n\nChoose GPU if your code uses CUDA, PyTorch, TensorFlow, or another library that needs a GPU."
          puts "\n4) #{pastel.blue('Array')}\n\nChoose array if you need to repeat the same job many times, usually with different files, parameters, or random seeds.\n"

          job_type = prompt.select(pastel.bold.magenta('What type of job would you like to run?'), types_of_job).split.first
          type_specific_questions = QUESTION_BANK[job_type.to_sym]

          system('clear')

          max_run_time = nil
          flags = {}
          puts max_run_time

          # ------------------------------------------------------------
          # Ask initial questions
          # ------------------------------------------------------------
          type_specific_questions.each_key do |key|
            system('clear')
            case key
            when :partition
              partition_question(flags, prompt, job_type, partition_info, pastel)
            when :job_name
              job_name_question(flags, prompt, pastel)
            when :time
              time_question(flags, partition_info, prompt, pastel)
            when :cpus_per_task
              cpus_per_task_question(flags, partition_info, pastel, prompt)
            end
          end

          puts flags

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          warn pastel.red("\nAn unexpected error occurred while running the command.")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end

        private

        # ------------------------------------------------------------
        # Question functions
        # ------------------------------------------------------------
        # Prompts the user for the job name
        # @param [Hash] flags
        # @param [TTY::Prompt] prompt
        # @param [Pastel::Delegator] pastel
        def job_name_question(flags, prompt, pastel)
          puts pastel.bold.blue("\nJob Name\n")
          puts "This is the name that will appear in the #{pastel.bold('SLURM queue')}."
          puts "Use a short, clear name so you can recognise the job later.\n"
          puts pastel.bright_black("Example: my_python_job\n")

          flags[:job_name] = prompt.ask(QUESTION_BANK[:partition], default: DEFAULT_VALUES[:job_name]) do |q|
            q.modify :strip
            q.convert ->(input) { input.gsub(/\s+/, '_') }
            q.validate do |input|
              cleaned = input.strip.gsub(/\s+/, '_')
              cleaned.match?(/\A[a-zA-Z0-9_.-]+\z/) && !cleaned.empty?
            end
            q.messages[:valid?] = 'Job name can only contain letters, numbers, underscores, dots, and hyphens.'
          end
        end

        # Prompts the user for the partition they want
        # @param [Hash] flags
        # @param [TTY::Prompt] prompt
        # @param [String] job_type
        # @param [Hash] partition_info
        # @param [Pastel::Delegator] pastel
        def partition_question(flags, prompt, job_type, partition_info, pastel)
          puts pastel.bold.cyan("\nPartition\n")
          puts "A partition is a queue or #{pastel.bold.underline('group of machines')} that your job can run on."
          puts "\nDifferent partitions may have different time limits, hardware, or waiting times."
          puts "\nIf you are unsure, choose the default partition.\n"
          puts "\nFor a #{pastel.bold("#{job_type} job")}, the available partitions are:"

          available_partitions =
            if [:gpu, 'gpu'].include?(job_type)
              partition_info.values.select { |partition| partition[:max_gpus].to_i.positive? }
            else
              partition_info.values
            end

          puts Terminal::Table.new(
            title: 'Available Partitions',
            headings: [
              'Partition',
              'Time Limit',
              'Node Count',
              'Max Memory Per Node',
              'Max CPU Cores Per Node',
              'GPU Count'
            ],
            rows: available_partitions.map do |partition|
              [
                partition[:name],
                Services::TimeConverter.to_human_readable(partition[:time_limit]),
                partition[:node_count],
                "#{partition[:max_memory_mb]} MB",
                partition[:max_cpu_cores],
                partition[:max_gpus]
              ]
            end
          )
          puts

          flags[:partition] = prompt.select(pastel.bold.cyan(QUESTION_BANK[:partition]), available_partitions.map { |partition| partition[:name] })
        end

        # Prompts the user for the max time of the script
        # @param [Hash] flags
        # @param [Hash] partition_info
        # @param [TTY::Prompt] prompt
        # @param [Pastel::Delegator] pastel
        def time_question(flags, partition_info, prompt, pastel)
          selected_partition = get_selected_partition(flags, partition_info, pastel)

          puts pastel.bold.magenta("\nTime\n")
          puts "In Slurm, time specifies the #{pastel.bold.underline('maximum time limit for a job')}.\n"
          puts "\nChoose enough time for your job to finish, but avoid asking for much more than you need.\n"
          puts "\nShorter jobs can sometimes start sooner.\n"

          max_run_time = selected_partition[:time_limit]
          human_readable_max_time = Services::TimeConverter.to_human_readable(max_run_time)

          puts "\nThe max runtime for the partition #{pastel.bold(selected_partition[:name])} is #{max_run_time}, i.e. #{human_readable_max_time}\n"

          flags[:time] = prompt.ask(pastel.bold.magenta(QUESTION_BANK[:time]), default: DEFAULT_VALUES[:time]) do |q|
            q.validate do |input|
              Services::TimeConverter.valid_slurm_time?(input, max_run_time)
            end
            q.messages[:valid?] = "Time must be in format D-HH:MM:SS and not exceed #{human_readable_max_time}"
          end
        end

        # Prompts the user for the amount of cpus per task
        # @param [Hash] flags
        # @param [Hash] partition_info
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        def cpus_per_task_question(flags, partition_info, pastel, prompt)
          selected_partition = get_selected_partition(flags, partition_info, pastel)

          max_cpu_cores = selected_partition[:max_cpu_cores].to_i

          puts pastel.bold.green("\nCPU Cores\n")
          puts "The #{pastel.bold('CPU')} (Central Processing Unit) is the brain of the computer.\n"
          puts "\nEach CPU contains a number of #{pastel.bold('cores')} that help your job do its work.\n"
          puts "\nMost normal Python, R, or shell scripts only use #{pastel.underline('1 core')}.\n"
          puts "\nAsk for more only if your code uses threading, multiprocessing, or software that can run in parallel.\n"
          puts "\nThe max number of cpu cores per node on partition #{selected_partition[:name]} is #{max_cpu_cores}.\n"

          flags[:cpus_per_task] = prompt.ask(pastel.bold.green(QUESTION_BANK[:cpus_per_task]), default: DEFAULT_VALUES[:cpus_per_task]) do |q|
            q.validate(/\A\d+\z/)
            q.messages[:valid?] = 'Please enter a whole number'
            q.validate do |input|
              input.to_i.between?(1, max_cpu_cores)
            end
            q.messages[:valid?] = "Please enter a whole number between 1 and #{max_cpu_cores}"
            q.convert :int
          end
        end

        # ------------------------------------------------------------
        # Ascii art functions
        # ------------------------------------------------------------
        # Handles side by side for the ascii art
        # @param [Hash] left
        # @param [Hash] right
        # @param [Integer] gap
        def side_by_side(left, right, gap: 4)
          left_lines = left.lines.map(&:chomp)
          right_lines = right.lines.map(&:chomp)
          height = [left_lines.length, right_lines.length].max
          left_width = left_lines.map(&:length).max || 0
          (0...height).map do |i|
            left_part = left_lines[i] || ''
            right_part = right_lines[i] || ''
            left_part.ljust(left_width + gap) + right_part
          end.join("\n")
        end

        # Handles multi line ascii art
        # @param [String] text
        # @param [Artii::Base] artii
        # @param [String] banner
        def asciify_multiline(text, artii, banner: nil)
          lines = text.split("\n", -1)
          art_lines = lines.map.with_index do |line, index|
            art = line.empty? ? '' : artii.asciify(line)
            if banner && index == lines.length - 1
              side_by_side(art, banner, gap: 4)
            else
              art
            end
          end

          art_lines.join("\n")
        end

        # Calls the artii animated title
        # @param [String] text
        # @param [Artii::Base] artii
        # @param [Pastel::Delegator] pastel
        # @param [Float] delay
        def animated_artii_title(text, artii, pastel, delay: 0.12)
          current = ''
          text.each_char do |char|
            current += char
            system('clear')
            show_banner = current == text
            puts pastel.bold.cyan(
              asciify_multiline(
                current,
                artii,
                banner: if show_banner
                          <<~BANNER
                            'o`
                            'ooo`
                            `oooo`
                             `oooo`         'o`
                               `ooooo`  `ooooo
                                  `oooo:oooo`
                                     `v
                          BANNER
                        end
              )
            )

            sleep(delay) unless char == "\n"
          end
        end

        # ------------------------------------------------------------
        # Get selected partition info
        # ------------------------------------------------------------
        # Gets the selected partitions information
        # @param [Hash] flags
        # @param [Hash] partition_info
        # @return [Hash]
        def get_selected_partition(flags, partition_info, pastel)
          selected_partition = partition_info.values.find do |partition|
            partition[:name] == flags[:partition]
          end

          unless selected_partition
            puts pastel.red("\nCould not find partition information for #{selected_partition[:name]}\n")
            exit(1)
          end

          selected_partition
        end

        # ------------------------------------------------------------
        # Valid sysinfo
        # ------------------------------------------------------------
        # Checks whether the partition information is valid
        # @param [Hash] partition_info
        # @return [Boolean]
        def valid_partition_info?(partition_info)
          return false unless partition_info.is_a?(Hash)
          return false if partition_info.empty?

          partition_info.values.all? do |partition|
            partition.is_a?(Hash) &&
              partition.key?(:name) &&
              partition.key?(:time_limit) &&
              partition.key?(:max_memory_mb) &&
              partition.key?(:max_cpu_cores)
          end
        end

        # ------------------------------------------------------------
        # Prompt for system info
        # ------------------------------------------------------------
        # Prompts the user for the partition information
        # @return [Hash]
        def prompt_for_partition_info
          prompt = TTY::Prompt.new

          puts Pastel.new.red("\nUnable to detect a Slurm environment. Please enter fallback cluster configuration for the system you wish to run the script on\n")

          partition_input = prompt.ask('Partition names (comma-separated)', default: 'default') do |q|
            q.required true
          end

          partition_names = partition_input.split(',').map(&:strip).reject(&:empty?)
          partition_names = ['default'] if partition_names.empty?

          partition_names.each_with_object({}).with_index do |(name, info), index|
            time_limit = prompt.ask("Max time for partition #{name}", default: '0-07:00:00') do |q|
              q.validate { |input| !TimeConverter.to_seconds(input).nil? }
              q.messages[:valid?] = 'time must be in format HH:MM:SS or D-HH:MM:SS'
            end

            max_cpu_cores = prompt.ask("Maximum CPU cores per node for partition #{name}", default: '4') do |q|
              q.validate(/\A\d+\z/)
              q.messages[:valid?] = 'Please enter a whole number.'
              q.convert :int
            end

            max_memory_mb = prompt.ask("Maximum memory per node for partition #{name} (MB)", default: '5000') do |q|
              q.validate do |input|
                !MemoryConverter.to_mb(input).nil?
              end

              q.messages[:valid?] = 'Please enter memory using M, MB, G, GB e.g. 5000M or 4G'

              q.convert do |input|
                MemoryConverter.to_mb(input)
              end
            end

            max_gpus = prompt.ask("Maximum GPUs per node for partition #{name}", default: '2') do |q|
              q.validate(/\A\d+\z/)
              q.messages[:valid?] = 'Please enter a whole number.'
              q.convert :int
            end

            node_count = prompt.ask("How many nodes are in partition #{name}?", default: '4') do |q|
              q.validate(/\A\d+\z/)
              q.messages[:valid?] = 'Please enter a whole number.'
              q.convert :int
            end

            info[name] = {
              name: name,
              default: index.zero?,
              max_memory_mb: max_memory_mb,
              max_cpu_cores: max_cpu_cores,
              max_gpus: max_gpus,
              node_count: node_count,
              time_limit: time_limit
            }
          end
        end
      end
    end
  end
end
