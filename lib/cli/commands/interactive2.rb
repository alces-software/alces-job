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
          partition_info = all_info[:partitions]
          package_info = all_info[:packages]

          unless valid_partition_info?(partition_info)
            partition_info = prompt_for_partition_info(prompt)
            package_info = prompt_for_packages(prompt)
          end

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
          system('clear')

          max_run_time = nil
          flags = {}
          puts max_run_time

          # ------------------------------------------------------------
          # Ask initial questions
          # ------------------------------------------------------------
          QUESTION_BANK[job_type.to_sym].each do |key, question|
            system('clear')
            case key
            when :partition
              partition_question(key, question, flags, pastel, prompt, job_type, partition_info)
            when :job_name
              job_name_question(key, question, flags, pastel, prompt)
            when :time
              time_question(key, question, flags, pastel, prompt, partition_info)
            when :cpus_per_task
              cpus_per_task_question(key, question, flags, pastel, prompt, partition_info)
            when :mem
              mem_question(key, question, flags, pastel, prompt, partition_info)
            when :command
              command_question(key, question, flags, pastel, prompt)
            when :prepare
              prepare_question(key, question, flags, pastel, prompt)
            when :modules
              modules_question(key, question, flags, pastel, prompt, package_info)
            when :nodes
              nodes_question(key, question, flags, pastel, prompt, partition_info)
            when :ntask
              ntask_question(key, question, flags, pastel, prompt, partition_info)
            when :gres
              gres_question(key, question, flags, pastel, prompt, partition_info)
            when :array
              array_question(key, question, flags, pastel, prompt)
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
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [TTY::Prompt] prompt
        # @param [Pastel::Delegator] pastel
        def job_name_question(key, question, flags, pastel, prompt)
          puts pastel.bold.blue("\nJob Name\n")
          puts "This is the name that will appear in the #{pastel.bold('SLURM queue')}."
          puts "Use a short, clear name so you can recognise the job later.\n"
          puts pastel.bright_black("Example: my_python_job\n")

          flags[key] = prompt.ask(question, default: DEFAULT_VALUES[key]) do |q|
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
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        # @param [String] job_type
        # @param [Hash] partition_info
        def partition_question(key, question, flags, pastel, prompt, job_type, partition_info)
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

          flags[key] = prompt.select(pastel.bold.cyan(question), available_partitions.map { |partition| partition[:name] })
        end

        # Prompts the user for the max time of the script
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        # @param [Hash] partition_info
        def time_question(key, question, flags, pastel, prompt, partition_info)
          selected_partition = get_selected_partition(flags, partition_info, pastel)

          puts pastel.bold.magenta("\nTime\n")
          puts "In Slurm, time specifies the #{pastel.bold.underline('maximum time limit for a job')}.\n"
          puts "\nChoose enough time for your job to finish, but avoid asking for much more than you need.\n"
          puts "\nShorter jobs can sometimes start sooner.\n"

          max_run_time = selected_partition[:time_limit]
          human_readable_max_time = Services::TimeConverter.to_human_readable(max_run_time)

          puts "\nThe max runtime for the partition #{pastel.bold(selected_partition[:name])} is #{max_run_time}, i.e. #{human_readable_max_time}\n\n"

          flags[key] = prompt.ask(pastel.bold.magenta(question), default: DEFAULT_VALUES[key]) do |q|
            q.validate do |input|
              Services::TimeConverter.valid_slurm_time?(input, max_run_time)
            end
            q.messages[:valid?] = "Time must be in format D-HH:MM:SS and not exceed #{human_readable_max_time}"
          end
        end

        # Prompts the user for the amount of cpus per task
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        # @param [Hash] partition_info
        def cpus_per_task_question(key, question, flags, pastel, prompt, partition_info)
          selected_partition = get_selected_partition(flags, partition_info, pastel)

          max_cpu_cores = selected_partition[:max_cpu_cores].to_i

          puts pastel.bold.green("\nCPU Cores\n")
          puts "The #{pastel.bold('CPU')} (Central Processing Unit) is the brain of the computer.\n"
          puts "\nEach CPU contains a number of #{pastel.bold('cores')} that help your job do its work.\n"
          puts "\nMost normal Python, R, or shell scripts only use #{pastel.underline('1 core')}.\n"
          puts "\nAsk for more only if your code uses threading, multiprocessing, or software that can run in parallel.\n"
          puts "\nThe max number of cpu cores per node on partition #{selected_partition[:name]} is #{max_cpu_cores}.\n\n"

          flags[key] = prompt.ask(pastel.bold.green(question), default: DEFAULT_VALUES[key]) do |q|
            q.validate(/\A\d+\z/)
            q.messages[:valid?] = 'Please enter a whole number'
            q.validate do |input|
              input.to_i.between?(1, max_cpu_cores)
            end
            q.messages[:valid?] = "Please enter a whole number between 1 and #{max_cpu_cores}"
            q.convert :int
          end
        end

        # Prompts the user for the amount of mem for the script
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        # @param [Hash] partition_info
        def mem_question(key, question, flags, pastel, prompt, partition_info)
          selected_partition = get_selected_partition(flags, partition_info, pastel)

          max_memory = selected_partition[:max_memory_mb].to_i

          puts pastel.bold.yellow("\nMemory\n")
          puts "Memory is the amount of #{pastel.yellow('RAM')} (Random Access Memory) your job needs while it is running.\n"
          puts "\nYour program uses RAM to hold #{pastel.bold('data')}, #{pastel.bold('variables')}, #{pastel.bold('files')} and #{pastel.bold('calculations')}.\n"
          puts "\nIf your job uses more memory than requested then Slurm may stop it.\n"
          puts "\nFor small scripts, 1024 - 2048 MB is often enough.\n"
          puts "\nThe maximum memory per node on partition #{selected_partition} is #{max_memory} MB.\n\n"

          flags[key] = prompt.ask(pastel.bold.yellow(question), default: DEFAULT_VALUES[key]) do |q|
            q.validate do |input|
              requested_memory_mb = Services::MemoryConverter.to_mb(input)
              !requested_memory_mb.nil? &&
                requested_memory_mb >= 1 &&
                requested_memory_mb <= max_memory
            end
            q.messages[:valid?] = "Enter memory between 1 MB and #{max_memory} MB, such as 500, 500M, or 2G."
            q.convert do |input|
              Services::MemoryConverter.to_mb(input)
            end
          end
        end

        # Prompts the user for the command they want in the script
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        def command_question(key, question, flags, pastel, prompt)
          puts pastel.bold.cyan("\nCommand\n")
          puts "This is the command that Slurm will run inside your batch script.\nUse the same command you would normally type into the terminal.\n"
          puts "\nExamples:\n\n"
          puts "#{pastel.bold.bright_magenta('python')} script.py\n\n"
          puts "#{pastel.bold.bright_magenta('R')} analysis.R\n\n"
          puts "#{pastel.bold.bright_magenta('node')} app.js\n\n"
          puts "#{pastel.bold.bright_magenta('srun')} ./my_mpi_program\n\n"

          flags[key] = prompt.ask(pastel.bold.cyan(question), default: DEFAULT_VALUES[key])
        end

        # Prompts the user whether they want prepare enabled
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        def prepare_question(key, question, flags, pastel, prompt)
          puts pastel.bold.cyan("\nJob Preparation\n")
          puts "This creates a dedicated working directory using the slurm job name and job ID.\n"
          puts "\nIt also adds output and errors to this directory.\n\n"

          flags[key] = prompt.yes?(pastel.bold.cyan(question), default: false)
        end

        # Prompts the user for which modules they want to load in their script
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        # @param [Hash] packages_info
        def modules_question(key, question, flags, pastel, prompt, packages_info)
          puts pastel.yellow.bold("\nScript Modules\n")
          puts "These are the modules that will be loaded into your script so they can be used within the script.\n"
          puts "\nThis is optional - you can either select multiple or none at all.\n"
          puts "\nTo select a modules, scroll down and press 'space'. If a module is selected, the icon will appear green.\n"
          puts "\nPress 'enter' with no sections to skip this stage.\n"

          options = {}
          packages_info.to_h.each_value do |package_group|
            package_group.each do |package|
              options["#{package[:name]} - v#{package[:version]}"] = package[:full_name] || "#{package[:name]}/#{package[:version]}"
            end
          end

          flags[key] = prompt.multi_select(pastel.bold.yellow(question), options, filter: true)
        end

        # Prompts the user for how many nodes they want to use for the script
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        # @param [Hash] partition_info
        def nodes_question(key, question, flags, pastel, prompt, partition_info)
          selected_partition = get_selected_partition(flags, partition_info, pastel)

          node_count = selected_partition[:node_count].to_i

          puts pastel.bold.blue("\nNodes\n")
          puts "A node is a #{pastel.bold.underline('single machine/computer')} in the cluster.\n"
          puts "\nMPI jobs may use multiple nodes to run work in parallel across machines.\n"
          puts "\nThe total number of nodes for partition #{selected_partition[:name]} is #{node_count}\n\n"

          flags[key] = prompt.ask(pastel.bold.blue(question), default: DEFAULT_VALUES[key]) do |q|
            q.validate(/\A\d+\z/)
            q.messages[:valid?] = 'Please enter a whole number'
            q.validate do |input|
              input.to_i.between?(1, node_count)
            end
            q.messages[:valid?] = "Please enter a whole number between 1 and #{node_count}"
            q.convert :int
          end
        end

        # Prompts the user for the array information for the script
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        def array_question(key, question, flags, pastel, prompt)
          max_array_size = 1001

          puts pastel.bold.bright_magenta("\nArray Job\n")
          puts "A Slurm array job runs the #{pastel.bold.underline('same job many times')} with different task IDs.\n"
          puts "\nThis is useful when you want to run the same script for many inputs, files, seeds, or parameters.\n"
          puts "\nEach array task gets its own ID through:\n\n"
          puts pastel.bold.green("$SLURM_ARRAY_TASK_ID\n")
          puts "Your script can use this ID to choose which file, row, or parameter to process.\n"
          puts pastel.bold("\nExamples:\n")
          puts "#{pastel.bold.bright_magenta('1-10')}       runs task IDs 1 through 10"
          puts "#{pastel.bold.bright_magenta('0-9')}        runs task IDs 0 through 9"
          puts "#{pastel.bold.bright_magenta('1,5,9')}      runs only task IDs 1, 5, and 9"
          puts "#{pastel.bold.bright_magenta('1-100%10')}   creates 100 tasks, but only runs 10 at the same time"
          puts "#{pastel.bold.bright_magenta('1-20:2')}     runs every 2nd task, e.g. 1, 3, 5 ... 19\n"
          puts "\nThe #{pastel.bold('%')} part limits how many array tasks can run at once."
          puts "For example, #{pastel.bold('1-100%10')} means run at most 10 tasks at the same time.\n"
          puts "\nIf you are unsure, start small, such as 1-5 or 1-10.\n\n"

          flags[key] = prompt.ask(pastel.bold.bright_magenta(question), default: DEFAULT_VALUES[key]) do |q|
            q.modify :strip
            q.validate do |input|
              array_value = input.strip
              next false if array_value.empty?
              next false unless array_value.match?(/\A[\d,\-:%]+\z/)

              max_array_index = max_array_size - 1
              valid_array = true
              array_parts, concurrency_limit = array_value.split('%', 2)

              if concurrency_limit &&
                 (!concurrency_limit.match?(/\A\d+\z/) || concurrency_limit.to_i < 1)
                valid_array = false
              end

              array_parts.split(',').each do |array_part|
                break unless valid_array

                range_part, step_value = array_part.split(':', 2)

                if step_value && (!step_value.match?(/\A\d+\z/) || step_value.to_i < 1)
                  valid_array = false
                  break
                end

                if range_part.include?('-')
                  array_range = range_part.match(/\A(\d+)-(\d+)\z/)

                  unless array_range
                    valid_array = false
                    break
                  end

                  end_value = array_range[2].to_i

                  if array_range[1].to_i > end_value || end_value > max_array_index
                    valid_array = false
                    break
                  end
                else
                  unless range_part.match?(/\A\d+\z/)
                    valid_array = false
                    break
                  end

                  if range_part.to_i > max_array_index
                    valid_array = false
                    break
                  end
                end
              end

              valid_array
            end
            q.messages[:valid?] = "Enter a valid array value between 0 and #{max_array_size - 1}, such as 1-10, 0-9, 1,5,9, 1-100%10, or 1-20:2."
          end
        end

        # Prompts the user for the gres settings for the script
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        # @param [Hash] partition_info
        def gres_question(key, question, flags, pastel, prompt, partition_info)
          selected_partition = get_selected_partition(flags, partition_info, pastel)

          max_gpus = selected_partition&.dig(:max_gpus).to_i

          puts pastel.bold.blue("\nGPUs\n")
          puts "\nA GPU (Graphics Processing Unit) is special processor used for highly parallel work, such as machine learning, simulations, and some scientific workloads.\n"

          if max_gpus.positive?
            puts "\nThe maximum number of GPUs on partition #{pastel.bold(selected_partition[:name])} is #{pastel.bold(max_gpus)} per node.\n"
          else
            puts pastel.red("\nThis partition does not appear to have any GPUs.\n")
            exit(1)
          end

          puts

          flags[key] = prompt.ask(pastel.bold.blue(question), default: DEFAULT_VALUES[key] || 1) do |q|
            q.validate do |input|
              input.to_s.match?(/\A\d+\z/) &&
                input.to_i.between?(1, max_gpus)
            end
            q.messages[:valid?] = "Please enter a whole number between 1 and #{max_gpus}"
            q.convert ->(input) { "gpu:#{input.to_i}" }
          end
        end

        # Prompts the user for the ntask settings for the script
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        # @param [Hash] partition_info
        def ntask_question(key, question, flags, pastel, prompt, partition_info)
          selected_partition = get_selected_partition(flags, partition_info, pastel)

          node_count = selected_partition[:node_count].to_i
          max_cpu_cores = selected_partition[:max_cpu_cores].to_i
          max_ntasks = node_count * max_cpu_cores

          puts pastel.bold.yellow("\nMPI Tasks\n")
          puts 'An MPI task is one parallel process in your MPI job.'
          puts "\nFor most beginner MPI jobs, each task is one copy of your MPI program running in parallel.\n"
          puts "\nFor partition #{selected_partition}, the rough maximum number of MPI tasks is #{max_ntasks}.\n"
          puts "\nThis is based on #{node_count} nodes multiplied by #{max_cpu_cores} CPU cores per node.\n\n"

          flags[key] = prompt.ask(pastel.bold.yellow(question), default: DEFAULT_VALUES[key]) do |q|
            q.validate do |input|
              input.to_s.match?(/\A\d+\z/) &&
                input.to_i.between?(1, max_ntasks)
            end
            q.messages[:valid?] = "Please enter a whole number between 1 and #{max_ntasks}"
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
        # @param [TTY::Prompt] prompt
        # @return [Hash]
        def prompt_for_partition_info(prompt)
          puts Pastel.new.red("\nUnable to detect a Slurm environment. Please enter fallback cluster configuration for the system you wish to run the script on\n")

          partition_input = prompt.ask('Partition names (comma-separated)', default: 'default') do |q|
            q.required true
          end

          partition_names = partition_input.split(',').map(&:strip).reject(&:empty?)
          partition_names = ['default'] if partition_names.empty?

          partition_names.each_with_object({}).with_index do |(name, info), index|
            time_limit = prompt.ask("Max time for partition #{name}", default: '0-07:00:00') do |q|
              q.validate { |input| !Services::TimeConverter.to_seconds(input).nil? }
              q.messages[:valid?] = 'time must be in format HH:MM:SS or D-HH:MM:SS'
            end

            max_cpu_cores = prompt.ask("Maximum CPU cores per node for partition #{name}", default: '4') do |q|
              q.validate(/\A\d+\z/)
              q.messages[:valid?] = 'Please enter a whole number.'
              q.convert :int
            end

            max_memory_mb = prompt.ask("Maximum memory per node for partition #{name} (MB)", default: '5000') do |q|
              q.validate do |input|
                !Services::MemoryConverter.to_mb(input).nil?
              end

              q.messages[:valid?] = 'Please enter memory using M, MB, G, GB e.g. 5000M or 4G'

              q.convert do |input|
                Services::MemoryConverter.to_mb(input)
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

        # Prompts the user for packages information
        # @param [TTY::Prompt] prompt
        # @return [Hash]
        def prompt_for_packages(prompt)
          module_input = prompt.ask('Available script modules/packages (comma-separated)', default: 'python/3.11,gcc/12.2,openmpi/4.1') do |q|
            q.convert ->(input) { input.to_s.strip }
          end

          module_names = module_input.split(',').map(&:strip).reject(&:empty?)

          return {} if module_names.empty?

          {
            custom: module_names.map do |full_name|
              parts = full_name.split('/')
              name = parts.first
              version = parts[1..]&.join('/')

              {
                full_name: full_name,
                name: name,
                version: version || 'default',
                description: 'User-provided module',
                deprecated: false
              }
            end
          }
        end
      end
    end
  end
end
