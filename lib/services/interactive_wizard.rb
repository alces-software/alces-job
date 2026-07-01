# frozen_string_literal: true

require 'tty-prompt'
require 'terminal-table'
require 'pastel'
require 'erb'
require 'tty-box'
require 'artii'

require_relative 'sys_info/sys_info'
require_relative 'paths/paths'
require_relative 'converters/time_converter'
require_relative 'converters/memory_converter'
require_relative 'config_manager/config_manager'
require_relative '../services/profile_manager/profile_manager'
require_relative 'editor/edit'
require_relative 'validators/slurm_script_validator'

module AlcesJob
  module Services
    class InteractiveWizard
      def initialize
        config_manager = AlcesJob::Services::ConfigManager.new({})
        @editor = config_manager.config[:editor]

        @info = AlcesJob::Services::SysInfo.load_info

        # @info = YAML.load_file('test_data.yaml')
        @info = deep_symbolize_keys(@info || {})
        @info = @info[:partitions]

        @info = prompt_for_system_info unless valid_partition_info?(@info)

        @banner = <<~BANNER
          'o`
          'ooo`#{'               '}
          `oooo`
           `oooo`         'o`#{' '}
             `ooooo`  `ooooo
                `oooo:oooo`
                   `v#{' '}
        BANNER
      end

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

      def asciify_multiline(text, artii, banner: nil)
        lines = text.split("\n", -1)

        art_lines = lines.map.with_index do |line, index|
          art = line.empty? ? '' : artii.asciify(line)

          # Put banner inline beside the final line only
          if banner && index == lines.length - 1
            side_by_side(art, banner, gap: 4)
          else
            art
          end
        end

        art_lines.join("\n")
      end

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
              banner: show_banner ? @banner : nil
            )
          )

          sleep(delay) unless char == "\n"
        end
      end

      def valid_partition_info?(info)
        return false unless info.is_a?(Hash)
        return false if info.empty?

        info.values.all? do |partition|
          partition.is_a?(Hash) &&
            partition.key?(:name) &&
            partition.key?(:time_limit) &&
            partition.key?(:max_memory_mb) &&
            partition.key?(:max_cpu_cores) &&
            partition.key?(:node_count) &&
            partition.key?(:max_gpus)
        end
      end

      def call
        system('clear')
        pastel = Pastel.new
        puts

        artii = Artii::Base.new(font: 'standard')

        puts pastel.bold.cyan(
          asciify_multiline("ALCES\nJOB\nINTERACTIVE", artii, banner: @banner)
        )

        puts pastel.bold.cyan('Welcome to the interactive wizard!')

        puts
        prompt = TTY::Prompt.new
        prompt.keypress("[Press #{pastel.bold('enter')} to continue] ")
        system('clear')

        max_run_time = nil

        partition_list = []

        @info.each_key do |partition|
          partition_list.append(partition)
        end

        types_of_job = ['serial (default)', 'mpi', 'gpu', 'array']

        puts

        puts pastel.underline.bold.cyan('Interactive Mode')

        puts "\nWelcome to Alces Job interactive mode."
        puts 'This wizard will help you build a SLURM batch script step by step.'

        puts "\nYou will be asked a few questions about your job, such as:"
        puts '  - what type of job you want to run'
        puts '  - how long the job should run for'
        puts '  - how much CPU and memory it needs'
        puts '  - what command should be executed'

        puts 'Helpful explanations and examples will be shown as you go.'
        puts "\nDo not worry if you are unsure - sensible default values will be provided."

        puts
        puts pastel.yellow('Tip: Enlarge your terminal screen for a better experience.')

        puts "\nAt the end, you will be able to preview the generated script before saving it.\n\n"

        key = prompt.keypress('[Press any key to continue, or q to quit]')
        system('clear')
        exit(0) if key == 'q'

        puts

        puts pastel.underline.magenta.bold('Job Types')
        puts "\nPlease specify what type of job you wish to run."
        puts "\n1) #{pastel.cyan('Serial job')}\n\nChoose this if your program runs normally on one machine and does not need GPUs or multiple parallel tasks.\n\n e.g. python script.py or Rscript analysis.R"
        puts "\n2) #{pastel.yellow('MPI (Message Passing Interface)')}\n\nChoose MPI if your program was written to run in parallel using MPI, or if the documentation tells you to run it with mpirun, mpiexec, or srun."
        puts "\n3) #{pastel.green('GPU (Graphics Processing Unit)')}\n\nChoose GPU if your code uses CUDA, PyTorch, TensorFlow, or another library that needs a GPU."
        puts "\n4) #{pastel.blue('Array')}\n\nChoose array if you need to repeat the same job many times, usually with different files, parameters, or random seeds."

        puts

        job_type = prompt.select(pastel.bold.magenta('What type of job would you like to run?'), types_of_job)

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
            nodes: 'How many nodes would you like to request?',
            ntasks: 'How many MPI tasks would you like per node?',
            time: 'How long would you like your job to run for?',
            cpus_per_task: 'How many CPU cores would each MPI task require?',

            mem: 'How much memory will your job use? (MB)',
            command: 'What MPI command would you like to run?'

          },

          gpu: {
            job_name: 'What is your job name?',
            partition: 'Which partition would you like to use?',
            time: 'How long would you like your job to run for?',
            gres: 'How many GPUs would you like to request?',
            cpus_per_task: 'How many CPU cores would you like to request?',
            mem: 'How much memory will your job use? (MB)',
            command: 'What command would you like to run?'
          },

          array: {
            job_name: 'What is your job name?',
            partition: 'Which partition would you like to use?',
            array: 'What array range would you like to use (e.g. 1-100)?',
            time: 'How long would you like your job to run for?',
            cpus_per_task: 'How many CPU cores should each array task use?',

            mem: 'How much memory would you like per array task? (MB)',
            command: 'What command would you like to run?'
          }
        }

        defaults = {
          job_name: 'my_slurm_job',
          time: '00-01:00:00',
          gres: '1',
          cpus_per_task: '1',
          ntasks: '1',
          array: '0-2',
          mem: '1024',
          nodes: '1',
          command: 'echo "Hello, World!"'
        }

        job_type = job_type.split[0] if job_type.split.length > 1

        selected_partition = nil

        system('clear')

        info = @info

        questions = question_bank[job_type.to_sym]

        result = prompt.collect do
          questions.each do |item, question|
            case item

            when :partition
              puts
              puts pastel.bold.cyan('Partition')
              puts "\nA partition is a queue or #{pastel.bold.underline('group of machines')} that your job can run on.\nDifferent partitions may have different time limits, hardware, or waiting times.\n"

              puts 'If you are unsure, choose the default partition.'
              puts
              puts "For a #{pastel.bold("#{job_type} job")}, the available partitions are:"
              puts

              available_partitions =
                if [:gpu, 'gpu'].include?(job_type)
                  info.values.select { |partition| partition[:max_gpus].to_i.positive? }
                else
                  info.values
                end

              partition_rows = available_partitions.map do |partition|
                [
                  partition[:name],
                  TimeConverter.to_human_readable(partition[:time_limit]),
                  partition[:node_count],
                  "#{partition[:max_memory_mb]} MB",
                  partition[:max_cpu_cores],
                  partition[:max_gpus]
                ]
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
                rows: partition_rows
              )
              puts

              selected_partition = key(item).select(pastel.bold.cyan(question), available_partitions.map { |partition| partition[:name] })

            when :ntasks
              selected_partition_info = info.values.find do |partition|
                partition[:name] == selected_partition
              end

              unless selected_partition_info
                puts "Could not find partition information for #{selected_partition}"
                exit(1)
              end

              node_count = selected_partition_info[:node_count].to_i
              max_cpu_cores = selected_partition_info[:max_cpu_cores].to_i
              max_ntasks = node_count * max_cpu_cores

              puts
              puts pastel.bold.blue('MPI Tasks')
              puts
              puts 'An MPI task is one parallel process in your MPI job.'
              puts 'For most beginner MPI jobs, each task is one copy of your MPI program running in parallel.'
              puts
              puts "For partition #{selected_partition}, the rough maximum number of MPI tasks is #{max_ntasks}."
              puts
              puts "This is based on #{node_count} nodes × #{max_cpu_cores} CPU cores per node."
              puts

              key(item).ask(pastel.bold.blue(question), default: defaults[item]) do |q|
                q.validate do |input|
                  input.to_s.match?(/\A\d+\z/) &&
                    input.to_i.between?(1, max_ntasks)
                end

                q.messages[:valid?] =
                  "Please enter a whole number between 1 and #{max_ntasks}"

                q.convert :int
              end

            when :array
              max_array_size = 1001
              puts
              puts pastel.bold.bright_magenta('Array Job')
              puts
              puts "A Slurm array job runs the #{pastel.bold.underline('same job many times')} with different task IDs."
              puts
              puts 'This is useful when you want to run the same script for many inputs, files, seeds, or parameters.'
              puts
              puts 'Each array task gets its own ID through:'
              puts
              puts pastel.bold.green('$SLURM_ARRAY_TASK_ID')
              puts
              puts 'Your script can use this ID to choose which file, row, or parameter to process.'
              puts

              puts pastel.bold('Examples:')
              puts
              puts "#{pastel.bold.bright_magenta('1-10')}       runs task IDs 1 through 10"
              puts "#{pastel.bold.bright_magenta('0-9')}        runs task IDs 0 through 9"
              puts "#{pastel.bold.bright_magenta('1,5,9')}      runs only task IDs 1, 5, and 9"
              puts "#{pastel.bold.bright_magenta('1-100%10')}   creates 100 tasks, but only runs 10 at the same time"
              puts "#{pastel.bold.bright_magenta('1-20:2')}     runs every 2nd task, e.g. 1, 3, 5 ... 19"
              puts

              puts "The #{pastel.bold('%')} part limits how many array tasks can run at once."
              puts "For example, #{pastel.bold('1-100%10')} means run at most 10 tasks at the same time."
              puts
              puts 'If you are unsure, start small, such as 1-5 or 1-10.'
              puts

              key(item).ask(pastel.bold.bright_magenta(question), default: defaults[item]) do |q|
                q.modify :strip

                q.validate do |input|
                  array_value = input.strip

                  next false if array_value.empty?

                  next false unless array_value.match?(/\A[\d,\-:%]+\z/)

                  max_array_index = max_array_size - 1

                  valid_array = true

                  array_parts, concurrency_limit = array_value.split('%', 2)

                  if concurrency_limit && !concurrency_limit.match?(/\A\d+\z/)
                    valid_array = false
                  elsif concurrency_limit && concurrency_limit.to_i < 1
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

                      start_value = array_range[1].to_i
                      end_value = array_range[2].to_i

                      if start_value > end_value || end_value > max_array_index
                        valid_array = false
                        break
                      end
                    else
                      unless range_part.match?(/\A\d+\z/)
                        valid_array = false
                        break
                      end

                      single_value = range_part.to_i

                      if single_value > max_array_index
                        valid_array = false
                        break
                      end
                    end
                  end

                  valid_array
                end

                q.messages[:valid?] =
                  "Enter a valid array value between 0 and #{max_array_size - 1}, such as 1-10, 0-9, 1,5,9, 1-100%10, or 1-20:2."
              end

            when :gres
              selected_partition_info = info.values.find do |partition|
                partition[:name] == selected_partition
              end
              max_gpus = selected_partition_info&.dig(:max_gpus).to_i

              puts
              puts pastel.bold.blue('GPUs')
              puts
              puts 'A GPU (Graphics Processing Unit) is special processor used for highly parallel work, such as machine learning, simulations, and some scientific workloads.'
              puts

              if max_gpus.positive?
                puts "The maximum number of GPUs on partition #{pastel.bold(selected_partition)} is #{pastel.bold(max_gpus)} per node."
              else
                puts pastel.red('This partition does not appear to have any GPUs.')
                exit(1)
              end

              puts

              key(item).ask(
                pastel.bold.blue(question),
                default: defaults[item] || 1
              ) do |q|
                q.validate do |input|
                  input.to_s.match?(/\A\d+\z/) &&
                    input.to_i.between?(1, max_gpus)
                end

                q.messages[:valid?] = "Please enter a whole number between 1 and #{max_gpus}"
                q.convert ->(input) { "gpu:#{input.to_i}" }
              end

            when :nodes
              selected_partition_info = info.values.find do |partition|
                partition[:name] == selected_partition
              end
              node_count = selected_partition_info[:node_count].to_i
              puts
              puts pastel.bold.blue('Nodes')
              puts "\nA node is a #{pastel.bold.underline('single machine/computer')} in the cluster. MPI jobs may use multiple nodes to run work in parallel across machines."
              puts
              puts "The total number of nodes for partition #{selected_partition} is #{node_count}"
              puts

              key(item).ask(pastel.bold.blue(question), default: defaults[item]) do |q|
                q.validate(/\A\d+\z/)
                q.messages[:valid?] = 'Please enter a whole number'
                q.validate do |input|
                  input.to_i.between?(1, node_count)
                end
                q.messages[:valid?] = "Please enter a whole number between 1 and #{node_count}"
                q.convert :int
              end

            when :time
              selected_partition_info = info.values.find do |partition|
                partition[:name] == selected_partition
              end

              unless selected_partition_info
                puts "Could not find partition information for #{selected_partition}"
                exit(1)
              end
              puts
              puts pastel.bold.magenta('Time')
              puts
              puts "In Slurm, time specifies the #{pastel.bold.underline('maximum time limit for a job')}. Choose enough time for your job to finish, but avoid asking for much more than you need. Shorter jobs can sometimes start sooner."

              unless selected_partition_info
                puts "Could not find partition information for #{selected_partition}"
                exit(1)
              end

              max_run_time = selected_partition_info[:time_limit]
              human_readable_max_time = TimeConverter.to_human_readable(max_run_time)

              puts "\nThe max runtime for the partition #{selected_partition} is #{max_run_time}, i.e. #{human_readable_max_time}"
              puts

              key(item).ask(pastel.bold.magenta(question), default: defaults[item]) do |q|
                q.validate do |input|
                  TimeConverter.valid_slurm_time?(input, max_run_time)
                end

                q.messages[:valid?] =
                  "Time must be in format D-HH:MM:SS and not exceed #{human_readable_max_time}"
              end

            when :mem
              selected_partition_info = info.values.find do |partition|
                partition[:name] == selected_partition
              end

              unless selected_partition_info
                puts "Could not find partition information for #{selected_partition}"
                exit(1)
              end

              max_memory = selected_partition_info[:max_memory_mb].to_i
              puts
              puts pastel.bold.yellow('Memory')
              puts
              puts "Memory is the amount of #{pastel.yellow('RAM')} (Random Access Memory) your job needs while it is running.\nYour program uses RAM to hold #{pastel.bold('data')}, #{pastel.bold('variables')}, #{pastel.bold('files')} and #{pastel.bold('calculations')}."
              puts
              puts "If your job uses more memory than requested then Slurm may stop it.\n"
              puts 'For small scripts, 1024 - 2048 MB is often enough.'
              puts
              puts "The maximum memory per node on partition #{selected_partition} is #{max_memory} MB."
              puts
              key(item).ask(pastel.bold.yellow(question), default: defaults[item]) do |q|
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

              selected_partition_info = info.values.find do |partition|
                partition[:name] == selected_partition
              end

              unless selected_partition_info
                puts "Could not find partition information for #{selected_partition}"
                exit(1)
              end

              max_cpu_cores = selected_partition_info[:max_cpu_cores].to_i

              puts
              puts pastel.bold.green('CPU Cores')
              puts
              puts "The #{pastel.bold('CPU')} (Central Processing Unit) is the brain of the computer. Each CPU contains a number of #{pastel.bold('cores')} that help your job do its work.\nMost normal Python, R, or shell scripts only use #{pastel.underline('1 core')}. Ask for more only if your code uses threading, multiprocessing, or software that can run in parallel."
              puts
              puts "The max number of cpu cores per node on partition #{selected_partition} is #{max_cpu_cores}."
              puts

              key(item).ask(pastel.bold.green(question), default: defaults[item]) do |q|
                q.validate(/\A\d+\z/)
                q.messages[:valid?] = 'Please enter a whole number'
                q.validate do |input|
                  input.to_i.between?(1, max_cpu_cores)
                end

                q.messages[:valid?] = "Please enter a whole number between 1 and #{max_cpu_cores}"
                q.convert :int
              end

            when :command
              puts
              puts pastel.bold.cyan('Command')
              puts
              puts "This is the command that Slurm will run inside your batch script.\nUse the same command you would normally type into the terminal."
              puts
              puts "Examples:\n"
              puts
              puts "#{pastel.bold.bright_magenta('python')} script.py"
              puts
              puts "#{pastel.bold.bright_magenta('R')} analysis.R"
              puts
              puts "#{pastel.bold.bright_magenta('node')} app.js"
              puts
              puts "#{pastel.bold.bright_magenta('srun')} ./my_mpi_program"
              puts
              puts
              key(item).ask(pastel.bold.cyan(question), default: defaults[item])

            when :job_name
              puts
              puts pastel.bold.blue('Job Name')
              puts
              puts "This is the name that will appear in the #{pastel.bold('SLURM queue')}."
              puts 'Use a short, clear name so you can recognise the job later.'
              puts
              puts pastel.bright_black('Example: my_python_job')
              puts
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

        # Edit Loop
        manual_editing = false
        valid_manual_editing = false
        final_script = nil

        editing_methods = ['Interactively', 'Manually (ADVANCED - only select if you have strong experience with text editors like vim, vi or nano.)']

        loop do
          job_type = 'universal' if job_type == 'serial'

          unless manual_editing
            generator = AlcesJob::Services::ScriptGenerator.new(
              result.merge(template: job_type)
            )
          end

          script = final_script || generator.generate

          puts

          box_width = script.lines.map { |line| line.chomp.length }.max + 4

          puts TTY::Box.frame(
            script,
            title: {
              top_center: pastel.bold.green(' Script Preview ')
            },
            padding: 1,
            border: :thick,
            width: box_width
          )
          puts

          break unless prompt.yes?('Would you like to edit any of your inputs?')

          editing_type = nil

          loop do
            backed_out = false
            puts
            editing_type = prompt.select('How would you like to edit your inputs?', editing_methods)

            break unless editing_type.start_with?('Manually')

            unless valid_manual_editing
              puts
              backed_out = prompt.no?(
                "#{pastel.bold.yellow('WARNING:')} Manual editing disables further interactive edits and profile saving for this session. Continue?"
              )
            end

            next if backed_out

            editing_methods.delete('Interactively')
            break
          end

          if editing_type.start_with?('Manually')
            manual_editing = true

            system('clear')

            old_script = script
            script = AlcesJob::Services::Editor.edit_script_in_editor(script, editor: @editor)

            Tempfile.create(['generated_script', '.slurm']) do |tempfile|
              tempfile.write(script)
              tempfile.flush

              validator = Services::SlurmScriptValidator.new(tempfile.path)

              if validator.validate?

                highlighted_script = AlcesJob::Services::Editor.highlight_added_lines(old_script, script, pastel)

                box_width = script.lines.map { |line| line.chomp.length }.max + 4
                puts

                puts TTY::Box.frame(
                  highlighted_script,
                  title: {
                    top_center: pastel.bold.green(' Edited Script Preview ')
                  },
                  padding: 1,
                  border: :thick,
                  width: box_width
                )

                AlcesJob::Services::Editor.show_removed_lines(old_script, script, pastel)

                puts
                if prompt.yes?('Do you want to save these changes?', default: true)
                  valid_manual_editing = true
                  final_script = script
                else
                  script = old_script
                  final_script = old_script
                  valid_manual_editing = true
                end
              else

                manual_editing = false
                editing_methods.unshift('Interactively') unless editing_methods.include?('Interactively') || valid_manual_editing
                script = old_script
                puts
                puts pastel.bold.red('INVALID SCRIPT')

                warn pastel.red("\nThe generated SBATCH script is not valid and changes were reverted.\n")

                validator.errors.each do |error|
                  warn "#{pastel.bold.red('ERROR')}: #{pastel.red(error)}"
                end

                validator.warnings.each do |warning|
                  warn pastel.yellow("Warning: #{warning}")
                end

                puts
                prompt.keypress("[Press #{pastel.bold('enter')} to return to editing]")

              end
            end

            system('clear')
            next

          end
          puts

          field = prompt.select(
            "Which input would you like to edit? #{pastel.dim('(scrollable)')}",
            result.keys
          )

          system('clear')

          case field
          when :partition
            puts
            puts pastel.bold.cyan('Partition')
            puts "\nA partition is a queue or #{pastel.underline('group of machines')} that your job can run on.\nDifferent partitions may have different time limits, hardware, or waiting times.\n"
            puts 'If you are unsure, choose the default partition.'
            puts

            puts "For a #{pastel.bold("#{job_type} job")}, the available partitions are:"
            puts

            available_partitions =
              if [:gpu, 'gpu'].include?(job_type)
                info.values.select { |partition| partition[:max_gpus].to_i.positive? }
              else
                info.values
              end

            partition_rows = available_partitions.map do |partition|
              [
                partition[:name],
                TimeConverter.to_human_readable(partition[:time_limit]),
                partition[:node_count],
                "#{partition[:max_memory_mb]} MB",
                partition[:max_cpu_cores],
                partition[:max_gpus]
              ]
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
              rows: partition_rows
            )
            puts

            selected_partition = prompt.select(
              pastel.bold.cyan(questions[:partition]),
              available_partitions.map { |partition| partition[:name] }
            )

            result[:partition] = selected_partition

            selected_partition_info = info.values.find do |partition|
              partition[:name] == result[:partition]
            end

            unless selected_partition_info
              puts "Could not find partition information for #{selected_partition}"
              exit(1)
            end

            max_run_time = selected_partition_info[:time_limit]
            human_readable_max_time = TimeConverter.to_human_readable(max_run_time)

            max_memory = selected_partition_info[:max_memory_mb].to_i
            max_cpu_cores = selected_partition_info[:max_cpu_cores].to_i

            node_count = selected_partition_info[:node_count].to_i

            unless TimeConverter.valid_slurm_time?(result[:time], max_run_time)

              puts "\nThe max runtime for the partition #{selected_partition} is #{max_run_time}, i.e. #{human_readable_max_time}"
              puts
              puts "Your current time value #{result[:time]} is #{pastel.bold('too high')} for #{selected_partition}."
              puts

              result[:time] = prompt.ask(
                pastel.bold.magenta(questions[:time]),
                default: defaults[:time]
              ) do |q|
                q.validate do |input|
                  TimeConverter.valid_slurm_time?(input, max_run_time)
                end

                q.messages[:valid?] =
                  "Time must be in format D-HH:MM:SS and not exceed #{human_readable_max_time}"
              end
            end

            if result[:mem].to_i > max_memory
              puts "\nThe max memory for the partition #{selected_partition} is #{max_memory} MB."
              puts
              puts "Your current memory value #{result[:mem]} MB is #{pastel.bold('too high')} for #{selected_partition}."
              puts

              result[:mem] = prompt.ask(
                pastel.bold.yellow(questions[:mem]),
                default: max_memory.to_s
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
            end

            if result[:cpus_per_task] && result[:cpus_per_task].to_i > max_cpu_cores
              puts "\nThe max CPU cores for the partition #{selected_partition} is #{max_cpu_cores}."
              puts
              puts "Your current CPU value #{result[:cpus_per_task]} is #{pastel.bold('too high')} for #{selected_partition}."
              puts

              result[:cpus_per_task] = prompt.ask(
                pastel.bold.green(questions[:cpus_per_task]),
                default: max_cpu_cores.to_s
              ) do |q|
                q.validate do |input|
                  input.match?(/\A\d+\z/) &&
                    input.to_i.between?(1, max_cpu_cores)
                end

                q.messages[:valid?] =
                  "Please enter a whole number between 1 and #{max_cpu_cores}"

                q.convert :int
              end

            end

            if result[:nodes] && result[:nodes] > node_count

              puts "\nThe total number of nodes for the partition #{selected_partition} is #{node_count}."
              puts
              puts "Your current selection of #{result[:nodes]} #{pastel.bold('exceeds')} the total node count for #{selected_partition}."
              puts

              result[:nodes] = prompt.ask(pastel.bold.blue(questions[:nodes]), default: result[:nodes]) do |q|
                q.validate(/\A\d+\z/)
                q.messages[:valid?] = 'Please enter a whole number'
                q.validate do |input|
                  input.to_i.between?(1, node_count)
                end
                q.messages[:valid?] = "Please enter a whole number between 1 and #{node_count}"
                q.convert :int
              end

            end

            if result[:ntasks] && result[:ntasks].to_i > max_cpu_cores * node_count
              max_ntasks = max_cpu_cores * node_count

              puts "\nThe rough max MPI task count for partition #{selected_partition} is #{max_ntasks}."
              puts
              puts "Your current ntasks value #{result[:ntasks]} is #{pastel.bold('too high')} for #{selected_partition}."
              puts

              result[:ntasks] = prompt.ask(
                pastel.bold.blue(questions[:ntasks]),
                default: max_ntasks.to_s
              ) do |q|
                q.validate do |input|
                  input.to_s.match?(/\A\d+\z/) &&
                    input.to_i.between?(1, max_ntasks)
                end

                q.messages[:valid?] =
                  "Please enter a whole number between 1 and #{max_ntasks}"

                q.convert :int
              end
            end

          when :ntasks
            selected_partition_info = info.values.find do |partition|
              partition[:name] == result[:partition]
            end

            unless selected_partition_info
              puts "Could not find partition information for #{result[:partition]}"
              exit(1)
            end

            node_count = selected_partition_info[:node_count].to_i
            max_cpu_cores = selected_partition_info[:max_cpu_cores].to_i
            max_ntasks = node_count * max_cpu_cores

            puts
            puts pastel.bold.blue('MPI Tasks')
            puts
            puts 'An MPI task is one parallel process in your MPI job.'
            puts 'For most beginner MPI jobs, each task is one copy of your MPI program running in parallel.'
            puts
            puts "For partition #{result[:partition]}, the rough maximum number of MPI tasks is #{max_ntasks}."
            puts
            puts "This is based on #{node_count} nodes × #{max_cpu_cores} CPU cores per node."
            puts

            result[:ntasks] = prompt.ask(
              pastel.bold.blue(questions[:ntasks]),
              default: result[:ntasks].to_s
            ) do |q|
              q.validate do |input|
                input.to_s.match?(/\A\d+\z/) &&
                  input.to_i.between?(1, max_ntasks)
              end

              q.messages[:valid?] =
                "Please enter a whole number between 1 and #{max_ntasks}"

              q.convert :int
            end

          when :gres
            selected_partition_info = info.values.find do |partition|
              partition[:name] == result[:partition]
            end
            max_gpus = selected_partition_info&.dig(:max_gpus).to_i

            puts
            puts pastel.bold.blue('GPUs')
            puts
            puts 'A GPU (Graphics Processing Unit) is special processor used for highly parallel work, such as machine learning, simulations, and some scientific workloads.'
            puts

            if max_gpus.positive?
              puts "The maximum number of GPUs on partition #{pastel.bold(selected_partition)} is #{pastel.bold(max_gpus)} per node."
            else
              puts pastel.red('This partition does not appear to have any GPUs.')
              exit(1)
            end

            puts

            result[:gres] = prompt.ask(
              pastel.bold.blue(questions[:gres]),
              default: defaults[:gres] || 1
            ) do |q|
              q.validate do |input|
                input.to_s.match?(/\A\d+\z/) &&
                  input.to_i.between?(1, max_gpus)
              end

              q.messages[:valid?] = "Please enter a whole number between 1 and #{max_gpus}"
              q.convert ->(input) { "gpu:#{input.to_i}" }
            end

          when :nodes
            selected_partition_info = info.values.find do |partition|
              partition[:name] == result[:partition]
            end
            node_count = selected_partition_info[:node_count].to_i
            puts
            puts pastel.bold.blue('Nodes')
            puts "\nA node is a #{pastel.bold.underline('single machine/computer')} in the cluster. MPI jobs may use multiple nodes to run work in parallel across machines."
            puts
            puts "The total number of nodes for partition #{selected_partition} is #{node_count}"
            puts

            result[:nodes] = prompt.ask(pastel.bold.blue(questions[:nodes]), default: result[:nodes]) do |q|
              q.validate(/\A\d+\z/)
              q.messages[:valid?] = 'Please enter a whole number'
              q.validate do |input|
                input.to_i.between?(1, node_count)
              end
              q.messages[:valid?] = "Please enter a whole number between 1 and #{node_count}"
              q.convert :int
            end

          when :time
            puts
            puts pastel.bold.magenta('Time')
            puts
            puts "In Slurm, time specifies the #{pastel.underline('maximum time limit for a job')}. Choose enough time for your job to finish, but avoid asking for much more than you need. Shorter jobs can sometimes start sooner."

            selected_partition_info = info.values.find do |partition|
              partition[:name] == result[:partition]
            end

            unless selected_partition_info
              puts "Could not find partition information for #{result[:partition]}"
              exit(1)
            end

            max_run_time = selected_partition_info[:time_limit]
            human_readable_max_time = TimeConverter.to_human_readable(max_run_time)

            puts "\nThe max runtime for the partition #{result[:partition]} is #{max_run_time}, i.e. #{human_readable_max_time}"
            puts

            result[:time] = prompt.ask(
              pastel.bold.magenta(questions[:time]),
              default: result[:time]
            ) do |q|
              q.validate do |input|
                TimeConverter.valid_slurm_time?(input, max_run_time)
              end

              q.messages[:valid?] =
                "Time must be in format D-HH:MM:SS and not exceed #{human_readable_max_time}"
            end

          when :mem
            selected_partition_info = info.values.find do |partition|
              partition[:name] == result[:partition]
            end

            unless selected_partition_info
              puts "Could not find partition information for #{result[:partition]}"
              exit(1)
            end

            max_memory = selected_partition_info[:max_memory_mb].to_i

            puts
            puts pastel.bold.yellow('Memory')
            puts
            puts "Memory is the amount of #{pastel.yellow('RAM')} (Random Access Memory) your job needs while it is running.\nYour program uses RAM to hold #{pastel.bold('data')}, #{pastel.bold('variables')}, #{pastel.bold('files')} and #{pastel.bold('calculations')}."
            puts "If your job uses more memory than requested then Slurm may stop it.\n"
            puts 'For small scripts, 1024 - 2048 MB is often enough.'
            puts
            puts "The maximum memory per node on partition #{result[:partition]} is #{max_memory} MB."
            puts

            result[:mem] = prompt.ask(
              pastel.bold.yellow(questions[:mem]),
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
            selected_partition_info = info.values.find do |partition|
              partition[:name] == result[:partition]
            end

            unless selected_partition_info
              puts "Could not find partition information for #{result[:partition]}"
              exit(1)
            end

            max_cpu_cores = selected_partition_info[:max_cpu_cores].to_i

            puts
            puts pastel.bold.green('CPU Cores')
            puts
            puts "The #{pastel.bold('CPU')} (Central Processing Unit) is the brain of the computer. Each CPU contains a number of #{pastel.bold('cores')} that help your job do its work.\nMost normal Python, R, or shell scripts only use #{pastel.underline('1 core')}. Ask for more only if your code uses threading, multiprocessing, or software that can run in parallel."
            puts
            puts "The max number of CPU cores per node on partition #{result[:partition]} is #{max_cpu_cores}."
            puts

            result[:cpus_per_task] = prompt.ask(
              pastel.bold.green(questions[:cpus_per_task]),
              default: result[:cpus_per_task].to_s
            ) do |q|
              q.validate do |input|
                input.match?(/\A\d+\z/) &&
                  input.to_i.between?(1, max_cpu_cores)
              end

              q.messages[:valid?] =
                "Please enter a whole number between 1 and #{max_cpu_cores}"

              q.convert :int
            end

          when :array
            max_array_size = 1001
            max_array_index = max_array_size - 1

            puts
            puts pastel.bold.bright_magenta('Array Job')
            puts
            puts 'An array job runs the same job multiple times using different task IDs.'
            puts
            puts "Each task gets a value through #{pastel.bold.green('$SLURM_ARRAY_TASK_ID')}."
            puts
            puts "This cluster currently allows array task IDs from 0 to #{max_array_index}."
            puts
            puts pastel.bold('Examples:')
            puts
            puts "#{pastel.bold.bright_magenta('1-10')}       runs task IDs 1 through 10"
            puts "#{pastel.bold.bright_magenta('0-9')}        runs task IDs 0 through 9"
            puts "#{pastel.bold.bright_magenta('1,5,9')}      runs only task IDs 1, 5, and 9"
            puts "#{pastel.bold.bright_magenta('1-100%10')}   creates 100 tasks, but only runs 10 at the same time"
            puts "#{pastel.bold.bright_magenta('1-20:2')}     runs every 2nd task, e.g. 1, 3, 5 ... 19"
            puts

            result[:array] = prompt.ask(
              questions[:array] || 'What array range would you like to use?',
              default: result[:array].to_s
            ) do |q|
              q.modify :strip

              q.validate do |input|
                array_value = input.strip

                next false if array_value.empty?

                next false unless array_value.match?(/\A[\d,\-:%]+\z/)

                valid_array = true

                array_parts, concurrency_limit = array_value.split('%', 2)

                if concurrency_limit && !concurrency_limit.match?(/\A\d+\z/)
                  valid_array = false
                elsif concurrency_limit && concurrency_limit.to_i < 1
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

                    start_value = array_range[1].to_i
                    end_value = array_range[2].to_i

                    if start_value > end_value || end_value > max_array_index
                      valid_array = false
                      break
                    end
                  else
                    unless range_part.match?(/\A\d+\z/)
                      valid_array = false
                      break
                    end

                    single_value = range_part.to_i

                    if single_value > max_array_index
                      valid_array = false
                      break
                    end
                  end
                end

                valid_array
              end

              q.messages[:valid?] =
                "Enter a valid array value between 0 and #{max_array_index}, such as 1-10, 0-9, 1,5,9, 1-100%10, or 1-20:2."
            end

          when :command
            puts
            puts pastel.bold.cyan('Command')
            puts
            puts "This is the command that Slurm will run inside your batch script.\nUse the same command you would normally type into the terminal."
            puts
            puts "Examples:\n"
            puts
            puts "#{pastel.bold.bright_magenta('python')} script.py"
            puts
            puts "#{pastel.bold.bright_magenta('R')} analysis.R"
            puts
            puts "#{pastel.bold.bright_magenta('node')} app.js"
            puts
            puts "#{pastel.bold.bright_magenta('srun')} ./my_mpi_program"
            puts
            puts
            result[:command] = prompt.ask(
              pastel.bold.cyan(questions[:command]),
              default: result[:command]
            )

          when :job_name
            puts
            puts pastel.bold.blue('Job Name')
            puts
            puts "This is the name that will appear in the #{pastel.bold('SLURM queue')}."
            puts 'Use a short, clear name so you can recognise the job later.'
            puts
            puts pastel.bright_black('Example: my_python_job')
            puts

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

              q.messages[:valid?] =
                'Job name can only contain letters, numbers, underscores, dots, and hyphens.'
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

        if valid_manual_editing && final_script
          final_script.lines.each do |line|
            next unless line.start_with?('#SBATCH')

            directive = line.sub(/\s+#.*\z/, '').strip
            option, value = directive.sub(/\A#SBATCH\s+/, '').split(/[=\s]+/, 2)
            value = value&.split&.first

            next unless option

            if ['--job-name', '-J'].include?(option)
              result[:job_name] = value
              break
            elsif option.start_with?('-J') && option.length > 2
              result[:job_name] = option[2..]
              break
            end
          end
        end

        final_options = result.merge(template: job_type)
        generator = AlcesJob::Services::ScriptGenerator.new(final_options)

        unless valid_manual_editing
          puts
          if prompt.yes?('Would you like to save these settings to a reusable profile?', default: false)
            profile_name = prompt.ask('What would you like to call the profile?') do |q|
              q.modify :strip
              q.convert ->(input) { input.gsub(/\s+/, '_') }

              q.validate do |input|
                cleaned = input.strip.gsub(/\s+/, '_')
                cleaned.match?(/\A[a-zA-Z0-9_.-]+\z/) && !cleaned.empty?
              end

              q.messages[:valid?] =
                'Profile name can only contain letters, numbers, underscores, dots, and hyphens.'
            end

            saved_profile_path = AlcesJob::Services::ProfileManager.save_profile(
              profile_name,
              final_options
            )

            puts pastel.green("Profile saved to #{saved_profile_path}")
          end
        end

        exit(0) unless prompt.yes?('Write script to file?')

        filename = File.basename(generator.file_path)

        exit(0) if File.exist?(generator.file_path) && !prompt.yes?("\nAn sbatch file with the name #{pastel.cyan(filename)} already exists. Do you want to overwrite it?", default: false)

        script_to_save = final_script || generator.generate

        file_path = generator.save(script_to_save)

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

        prompt_for_partitions(prompt)
      end

      def prompt_for_partitions(prompt)
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
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  end
end
