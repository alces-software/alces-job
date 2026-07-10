# frozen_string_literal: true

require 'dry/cli'
require 'tty-prompt'
require 'terminal-table'
require 'pastel'
require 'erb'
require 'tty-box'
require 'artii'
require 'io/console'

require_relative '../../services/sys_info/sys_info'
require_relative '../../services/paths/paths'
require_relative '../../services/converters/time_converter'
require_relative '../../services/converters/memory_converter'
require_relative '../../services/profile_manager/profile_manager'
require_relative '../../services/config_manager/config_manager'

module AlcesJob
  module CLI
    module Commands
      class Interactive < Dry::CLI::Command
        AlcesJob::CLI.register 'interactive', self, aliases: ['-i', '--interactive']

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
            track: 'Would you like tracking methods to be injected into the script?',
            prepare: 'Would you like to prepare this job with a dedicated working directory?'
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
            track: 'Would you like tracking methods to be injected into the script?',
            prepare: 'Would you like to prepare this job with a dedicated working directory?'
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
            track: 'Would you like tracking methods to be injected into the script?',
            prepare: 'Would you like to prepare this job with a dedicated working directory?'
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
            track: 'Would you like tracking methods to be injected into the script?',
            prepare: 'Would you like to prepare this job with a dedicated working directory?'
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
          prompt = TTY::Prompt.new

          # ------------------------------------------------------------
          # System information
          # ------------------------------------------------------------
          all_info = Services::SysInfo.load_info
          partition_info = all_info[:partitions]
          package_info = all_info[:packages]
          @max_array_size = all_info[:max_array_size]

          unless valid_partition_info?(partition_info)
            partition_info = prompt_for_partition_info(prompt)
            package_info = prompt_for_packages(prompt)
          end

          # ------------------------------------------------------------
          # Welcome message
          # ------------------------------------------------------------
          system('clear')
          animation(pastel)
          puts pastel.bold.cyan("\nWelcome to Interactive Mode!\n")
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
          puts "\nDo not worry if you are unsure - sensible default values will be provided.\n\n"
          puts pastel.yellow('Tip: Enlarge your terminal screen for a better experience.')
          puts "\nAt the end, you will be able to preview the generated script before saving it.\n\n"
          key = prompt.keypress("[Press #{pastel.bold('any key')} to continue, or q to quit]")
          system('clear')
          exit(0) if key == 'q'
          puts pastel.underline.magenta.bold("\nJob Types")
          puts "\nPlease specify what type of job you wish to run."
          puts "\n1) #{pastel.cyan('Serial job')}\n\nChoose this if your program runs normally on one machine and does not need GPUs or multiple parallel tasks.\n\n e.g. python script.py or Rscript analysis.R"
          puts "\n2) #{pastel.yellow('MPI (Message Passing Interface)')}\n\nChoose MPI if your program was written to run in parallel using MPI, or if the documentation tells you to run it with mpirun, mpiexec, or srun."
          puts "\n3) #{pastel.green('GPU (Graphics Processing Unit)')}\n\nChoose GPU if your code uses CUDA, PyTorch, TensorFlow, or another library that needs a GPU."
          puts "\n4) #{pastel.blue('Array')}\n\nChoose array if you need to repeat the same job many times, usually with different files, parameters, or random seeds.\n\n"
          job_type = prompt.select(
            pastel.bold.magenta('What type of job would you like to run?'),
            types_of_job,
            per_page: 10
          ).split.first
          job_specific_questions = QUESTION_BANK[job_type.to_sym]
          system('clear')

          config_manager = Services::ConfigManager.new({})

          flags = config_manager.config
          blacklisted_modules = config_manager.module_blacklist

          # ------------------------------------------------------------
          # Ask initial questions
          # ------------------------------------------------------------
          job_specific_questions.each do |key, question|
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
              modules_question(key, question, flags, pastel, prompt, package_info, blacklisted_modules)
            when :nodes
              nodes_question(key, question, flags, pastel, prompt, partition_info)
            when :ntasks
              ntask_question(key, question, flags, pastel, prompt, partition_info)
            when :gres
              gres_question(key, question, flags, pastel, prompt, partition_info)
            when :array
              array_question(key, question, flags, pastel, prompt)
            when :track
              track_question(key, question, flags, pastel, prompt)
            end
          end

          # ------------------------------------------------------------
          # Edit loop
          # ------------------------------------------------------------
          final_script = nil
          manual_editing = false
          valid_manual_editing = false
          editing_methods = ['Interactively', 'Manually (ADVANCED - only select if you have strong experience with text editors like vim, vi or nano.)']

          loop do
            generator = AlcesJob::Services::ScriptGenerator.new(flags.merge(template: job_type)) unless manual_editing
            script = final_script || generator.generate
            system('clear')

            puts "\n#{TTY::Box.frame(
              script,
              title: {
                top_center: pastel.bold.green(' Script Preview ')
              },
              padding: 1,
              border: :thick,
              width: (script.lines.map { |line| line.chomp.length }.max || 0) + 4
            )}\n"

            break unless prompt.yes?('Would you like to edit any of your inputs?', default: false)

            editing_type = nil

            loop do
              backed_out = false
              editing_type = prompt.select(
                "\nHow would you like to edit your inputs?",
                editing_methods,
                per_page: 10
              )

              break unless editing_type.start_with?('Manually')

              backed_out = prompt.no?("\n#{pastel.bold.yellow('WARNING:')} Manual editing disables further interactive edits and profile saving for this session. Continue?") unless valid_manual_editing
              next if backed_out

              editing_methods.delete('Interactively')
              break
            end

            if editing_type.start_with?('Manually')
              system('clear')
              manual_editing = true
              old_script = script
              script = AlcesJob::Services::Editor.edit_script_in_editor(script, editor: @editor)
              Tempfile.create(['generated_script', '.slurm']) do |tempfile|
                tempfile.write(script)
                tempfile.flush
                validator = Services::SlurmScriptValidator.new(tempfile.path)
                if validator.validate?
                  begin
                    edited_script = AlcesJob::Services::Editor.highlight_added_lines(old_script, script, pastel)
                  rescue StandardError
                    edited_script = script
                  end

                  box_width = (script.lines.map { |line| line.chomp.length }.max || 0) + 4
                  puts "\n#{TTY::Box.frame(
                    edited_script,
                    title: {
                      top_center: pastel.bold.green(' Edited Script Preview ')
                    },
                    padding: 1,
                    border: :thick,
                    width: box_width
                  )}"

                  begin
                    AlcesJob::Services::Editor.show_removed_lines(old_script, script, pastel)
                  rescue StandardError
                    puts pastel.bold.yellow("WARNING: No diff executable found - can't show difference in script. Proceed with caution.")
                  end
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
                  puts pastel.bold.red("\nINVALID SCRIPT")
                  warn pastel.red("\nThe generated SBATCH script is not valid and changes were reverted.\n")
                  validator.errors.each do |error|
                    warn "#{pastel.bold.red('ERROR')}: #{pastel.red(error)}"
                  end
                  validator.warnings.each do |warning|
                    warn pastel.yellow("Warning: #{warning}")
                  end
                  prompt.keypress("\n[Press #{pastel.bold('enter')} to return to editing]")
                end
              end
              system('clear')
              next
            end

            field = prompt.select("Which input would you like to edit? #{pastel.dim('(scrollable)')}",
                                  flags.keys.filter do |key|
                                    job_specific_questions.key?(key)
                                  end,
                                  per_page: 10)

            system('clear')

            case field
            when :partition
              previous_partition = flags[:partition]
              partition_question(field, job_specific_questions[field], flags, pastel, prompt, job_type, partition_info)
              if previous_partition != flags[:partition]
                selected_partition = get_selected_partition(flags, partition_info, pastel)
                max_run_time = selected_partition[:time_limit]
                human_readable_max_time = Services::TimeConverter.to_human_readable(max_run_time)
                max_memory = selected_partition[:max_memory_mb].to_i
                max_cpu_cores = selected_partition[:max_cpu_cores].to_i
                node_count = selected_partition[:node_count].to_i

                unless Services::TimeConverter.valid_slurm_time?(flags[:time], max_run_time)
                  puts "\nThe max runtime for the partition #{selected_partition[:name]} is #{max_run_time}, i.e. #{human_readable_max_time}\n"
                  puts "Your current time value #{flags[:time]} is #{pastel.bold('too high')} for #{selected_partition[:name]}.\n"
                  flags[:time] = prompt.ask(pastel.bold.magenta(job_specific_questions[:time]), default: DEFAULT_VALUES[:time]) do |q|
                    q.validate do |input|
                      Services::TimeConverter.valid_slurm_time?(input, max_run_time)
                    end
                    q.messages[:valid?] = "Time must be in format D-HH:MM:SS and not exceed #{human_readable_max_time}"
                  end
                end

                if flags[:mem].to_i > max_memory
                  puts "\nThe max memory for the partition #{selected_partition[:name]} is #{max_memory} MB.\n"
                  puts "Your current memory value #{flags[:mem]} MB is #{pastel.bold('too high')} for #{selected_partition[:name]}.\n"
                  flags[:mem] = prompt.ask(pastel.bold.yellow(job_specific_questions[:mem]), default: max_memory.to_s) do |q|
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

                if flags[:cpus_per_task] && flags[:cpus_per_task].to_i > max_cpu_cores
                  puts "\nThe max CPU cores for the partition #{selected_partition[:name]} is #{max_cpu_cores}.\n"
                  puts "Your current CPU value #{flags[:cpus_per_task]} is #{pastel.bold('too high')} for #{selected_partition[:name]}.\n"
                  flags[:cpus_per_task] = prompt.ask(pastel.bold.green(job_specific_questions[:cpus_per_task]), default: max_cpu_cores.to_s) do |q|
                    q.validate do |input|
                      input.match?(/\A\d+\z/) &&
                        input.to_i.between?(1, max_cpu_cores)
                    end
                    q.messages[:valid?] = "Please enter a whole number between 1 and #{max_cpu_cores}"
                    q.convert :int
                  end
                end

                if flags[:nodes] && flags[:nodes] > node_count
                  puts "\nThe total number of nodes for the partition #{selected_partition[:name]} is #{node_count}.\n"
                  puts "Your current selection of #{flags[:nodes]} #{pastel.bold('exceeds')} the total node count for #{selected_partition[:name]}.\n"
                  flags[:nodes] = prompt.ask(pastel.bold.blue(job_specific_questions[:nodes]), default: flags[:nodes]) do |q|
                    q.validate(/\A\d+\z/)
                    q.messages[:valid?] = 'Please enter a whole number'
                    q.validate do |input|
                      input.to_i.between?(1, node_count)
                    end
                    q.messages[:valid?] = "Please enter a whole number between 1 and #{node_count}"
                    q.convert :int
                  end

                end

                if flags[:ntasks] && flags[:ntasks].to_i > max_cpu_cores * node_count
                  max_ntasks = max_cpu_cores * node_count
                  puts "\nThe rough max MPI task count for partition #{selected_partition[:name]} is #{max_ntasks}.\n"
                  puts "Your current ntasks value #{flags[:ntasks]} is #{pastel.bold('too high')} for #{selected_partition[:name]}.\n"
                  flags[:ntasks] = prompt.ask(pastel.bold.blue(job_specific_questions[:ntasks]), default: max_ntasks.to_s) do |q|
                    q.validate do |input|
                      input.to_s.match?(/\A\d+\z/) &&
                        input.to_i.between?(1, max_ntasks)
                    end
                    q.messages[:valid?] = "Please enter a whole number between 1 and #{max_ntasks}"
                    q.convert :int
                  end
                end
              end
            when :ntasks
              ntask_question(field, job_specific_questions[field], flags, pastel, prompt, partition_info)
            when :nodes
              nodes_question(field, job_specific_questions[field], flags, pastel, prompt, partition_info)
            when :time
              time_question(field, job_specific_questions[field], flags, pastel, prompt, partition_info)
            when :mem
              mem_question(field, job_specific_questions[field], flags, pastel, prompt, partition_info)
            when :cpus_per_task
              cpus_per_task_question(field, job_specific_questions[field], flags, pastel, prompt, partition_info)
            when :array
              array_question(field, job_specific_questions[field], flags, pastel, prompt)
            when :prepare
              prepare_question(field, job_specific_questions[field], flags, pastel, prompt)
            when :job_name
              job_name_question(field, job_specific_questions[field], flags, pastel, prompt)
            when :modules
              modules_question(field, job_specific_questions[field], flags, pastel, prompt, package_info, blacklisted_modules)
            when :command
              command_question(field, job_specific_questions[field], flags, pastel, prompt)
            when :track
              track_question(field, job_specific_questions[field], flags, pastel, prompt)
            end

            next unless valid_manual_editing && final_script

            final_script.lines.each do |line|
              next unless line.start_with?('#SBATCH')

              directive = line.sub(/\s+#.*\z/, '').strip
              option, value = directive.sub(/\A#SBATCH\s+/, '').split(/[=\s]+/, 2)
              value = value&.split&.first

              next unless option

              if ['--job-name', '-J'].include?(option)
                flags[:job_name] = value
                break
              elsif option.start_with?('-J') && option.length > 2
                flags[:job_name] = option[2..]
                break
              end
            end
          end

          generator = AlcesJob::Services::ScriptGenerator.new(flags.merge(template: job_type))

          # ------------------------------------------------------------
          # Save profile
          # ------------------------------------------------------------
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

              saved_profile_path = AlcesJob::Services::ProfileManager.save_profile(profile_name, flags)
              puts pastel.green("Profile saved to #{saved_profile_path}")
            end
          end

          # ------------------------------------------------------------
          # Final questions and save script
          # ------------------------------------------------------------
          exit(0) unless prompt.yes?("\nWrite script to file?")
          exit(0) if File.exist?(generator.file_path) && !prompt.yes?("\nAn sbatch file with the name #{pastel.cyan(File.basename(generator.file_path))} already exists. Do you want to overwrite it?", default: false)
          script_to_save = final_script || generator.generate
          file_path = generator.save(script_to_save)
          puts "\nScript has been saved to #{file_path}"
          exit(0) unless prompt.yes?("\nWould you like to submit the job to SBATCH?", default: false)
          stdout, status = generator.submit(file_path)
          unless status.success?
            puts pastel.red("\nAn error occurred\n")
            exit(1)
          end
          puts "\n#{stdout}\n"
          exit(0)

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
          puts "Use a short, clear name so you can recognise the job later.\n\n"
          puts pastel.bright_black("Example: my_python_job\n")

          flags[key] = prompt.ask(pastel.bold.blue(question), default: flags[key] || DEFAULT_VALUES[key]) do |q|
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
          puts "A partition is a queue or #{pastel.bold.underline('group of machines')} that your job can run on.\nDifferent partitions may have different time limits, hardware, or waiting times.\n"
          puts "\nIf you are unsure, choose the default partition.\n\n"
          puts "For a #{pastel.bold("#{job_type} job")}, the available partitions are:\n\n"

          available_partitions =
            if [:gpu, 'gpu'].include?(job_type)
              partition_info.values.select { |partition| partition[:max_gpus].to_i.positive? }
            else
              partition_info.values
            end

          puts "#{Terminal::Table.new(
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
          )}\n\n"

          flags[key] = prompt.select(pastel.bold.cyan(question), available_partitions.map { |partition| partition[:name] }, per_page: 10) do |menu|
            menu.default(partition_info.keys.find_index(flags[:partition].to_sym) + 1) if !flags[:partition].nil? && partition_info.key?(flags[:partition].to_sym)
          end
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
          puts "In Slurm, time specifies the #{pastel.bold.underline('maximum time limit for a job')}. Choose enough time for your job to finish, but avoid asking for much more than you need.\nShorter jobs can sometimes start sooner.\n"

          max_run_time = selected_partition[:time_limit]
          human_readable_max_time = Services::TimeConverter.to_human_readable(max_run_time)

          puts "\nThe max runtime for the partition #{pastel.bold(selected_partition[:name])} is #{max_run_time}, i.e. #{human_readable_max_time}\n\n"

          flags[key] = prompt.ask(pastel.bold.magenta(question), default: flags[key] || DEFAULT_VALUES[key]) do |q|
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
          puts "The #{pastel.bold('CPU')} (Central Processing Unit) is the brain of the computer. Each CPU contains a number of #{pastel.bold('cores')} that help your job do its work.\n\nMost normal Python, R, or shell scripts only use #{pastel.underline('1 core')}. Ask for more only if your code uses threading, multiprocessing, or software that can run in parallel.\n\n"
          puts "The max number of CPU cores per node on partition #{pastel.bold(selected_partition[:name])} is #{max_cpu_cores}.\n\n"

          flags[key] = prompt.ask(pastel.bold.green(question), default: flags[key] || DEFAULT_VALUES[key]) do |q|
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
          puts "Memory is the amount of #{pastel.yellow('RAM')} (Random Access Memory) your job needs while it is running.\nYour program uses RAM to hold #{pastel.bold('data')}, #{pastel.bold('variables')}, #{pastel.bold('files')} and #{pastel.bold('calculations')}.\n\n"
          puts "If your job uses more memory than requested then Slurm may stop it.\n"
          puts "For small scripts, 1024 - 2048 MB is often enough.\n\n"
          puts "The maximum memory per node on partition #{pastel.bold(selected_partition[:name])} is #{max_memory} MB.\n\n"

          flags[key] = prompt.ask(pastel.bold.yellow(question), default: flags[key] || DEFAULT_VALUES[key]) do |q|
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
          puts "This is the command that Slurm will run inside your batch script.\nUse the same command you would normally type into the terminal.\n\n"
          puts "Examples:\n\n"
          puts "#{pastel.bold.bright_magenta('python')} script.py\n\n"
          puts "#{pastel.bold.bright_magenta('R')} analysis.R\n\n"
          puts "#{pastel.bold.bright_magenta('node')} app.js\n\n"
          puts "#{pastel.bold.bright_magenta('srun')} ./my_mpi_program\n\n"

          flags[key] = prompt.ask(pastel.bold.cyan(question), default: flags[key] || DEFAULT_VALUES[key])
        end

        # Prompts the user whether they want prepare enabled
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        def prepare_question(key, question, flags, pastel, prompt)
          job_name = flags[:job_name] || DEFAULT_VALUES[:job_name]
          puts pastel.bold.magenta("\nJob Preparation\n")
          puts "This will create a #{pastel.bold('dedicated working directory')} for this job using the job name and job ID. This step is #{pastel.underline('optional')}."
          puts "\nThe job output and error files will be saved inside that folder, so everything stays in one place.\n"
          puts "This keeps your filesystem #{pastel.underline('nice and tidy')} and prevents unintended clutter.\n\n"
          puts pastel.bold('Example:')
          puts "\nYour job name of #{pastel.bold(job_name)} will create a directory named #{pastel.bold.cyan("#{job_name}-<JOB_ID>")} that will store all output and error files for your job.\n\n"

          flags[key] = prompt.yes?(pastel.bold.magenta(question), default: flags[key] || false)
        end

        # Prompts the user for the job name
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [TTY::Prompt] prompt
        # @param [Pastel::Delegator] pastel
        def track_question(key, question, flags, pastel, prompt)
          puts pastel.bold.green("\nJob Tracking\n")
          puts "This will source and inject tracking functions into your script. \nThis step is #{pastel.underline('optional')}."
          puts "\nWhen you run a job script with the tracking functions inside it, \nyou can see the progress of your script using #{pastel.bold.cyan('alces-job status <JOB_ID>')}"
          puts "\nIf you have multiple sections in your script, you can wrap them \nwith #{pastel.cyan('alces_start_stage')} and #{pastel.cyan('alces_end_stage')} so that they can be tracked.\n\n"
          return unless prompt.yes?(pastel.bold.green(question), default: flags[key] || false)

          spec = Gem.loaded_specs['alces-job']
          unless spec
            pastel.red("\nCould not locate gem environment. Are you sure you have installed the gem?\n")
            prompt.keypress('[Press any key to continue, or q to quit]')
            return
          end

          lib_path = File.join(spec.full_gem_path, 'lib/helper_functions/functions.bash')
          job_path = Services::Paths.new.user_job_dir
          flags[:tracking_path] = lib_path
          flags[:job_path] = job_path
          flags[key] = true
        end

        # Prompts the user for which modules they want to load in their script
        # @param [Symbol] key
        # @param [String] question
        # @param [Hash] flags
        # @param [Pastel::Delegator] pastel
        # @param [TTY::Prompt] prompt
        # @param [Hash] packages_info
        # @param [Array] blacklisted_modules
        def modules_question(key, question, flags, pastel, prompt, packages_info, blacklisted_modules)
          return if packages_info.empty?

          puts pastel.yellow.bold("\nModules\n")

          puts "Modules are #{pastel.bold('software packages')} that can be loaded before your job runs."
          puts "For example, a module might make Python, R, CUDA, or another tool available inside your script.\n\n"

          puts "This step is #{pastel.underline('optional')}."
          puts "You can choose one or more modules, or skip this step if your script does not need any.\n\n"

          puts 'Use the arrow keys to move through the list.'
          puts "Press 'space' to select or deselect a module."
          puts 'Selected modules will be highlighted with a green icon.'
          puts "Press 'enter' when you are finished.\n\n"

          puts "To skip this step, press 'enter' without selecting anything.\n\n"

          options = []
          already_selected = []
          count = 0

          packages_info.to_h.each_value do |package_group|
            package_group.each do |package|
              count += 1
              already_selected << count if flags[:modules]&.include?(package[:full_name])
              options << if blacklisted_modules&.include?(package[:full_name])
                           {
                             name: package[:full_name],
                             disabled: ' - Blocked by config'
                           }
                         else
                           package[:full_name]
                         end
            end
          end

          flags[key] = prompt.multi_select(
            pastel.bold.yellow(question),
            options,
            filter: true,
            per_page: 10
          ) do |menu|
            menu.default(*already_selected) unless already_selected.empty?
          end

          return if flags[key].empty?

          deprecated_module = false

          puts
          packages_info.to_h.each_value do |package_group|
            package_group.each do |package|
              next unless flags[key].include?(package[:full_name])

              if package[:deprecated]
                deprecated_module = true
                puts pastel.yellow("#{package[:full_name]} is deprecated")
              end

              next unless !package[:dependency]&.nil? && !package[:dependency]&.empty?

              package[:dependency].each do |dep|
                flags[key].push(dep) unless flags[key].include?(dep)
              end
            end
          end

          return unless deprecated_module

          return unless prompt.yes?("\nOne or more of your selected modules are deprecated, would you like to change your selection?", default: false)

          system('clear')
          modules_question(key, question, flags, pastel, prompt, packages_info, blacklisted_modules)
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
          puts "A node is a #{pastel.bold.underline('single machine/computer')} in the cluster. MPI jobs may use multiple nodes to run work in parallel across machines.\n\n"
          puts "The total number of nodes for partition #{pastel.bold(selected_partition[:name])} is #{node_count}\n\n"

          flags[key] = prompt.ask(pastel.bold.blue(question), default: flags[key] || DEFAULT_VALUES[key]) do |q|
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
          max_array_size = 1001 if max_array_size.is_a?(Hash) && max_array_size.empty?
          puts pastel.bold.bright_magenta("\nArray Job\n")
          puts "A Slurm array job runs the #{pastel.bold.underline('same job many times')} with different task IDs.\n\n"
          puts "This is useful when you want to run the same script for many inputs, files, seeds, or parameters.\n\n"
          puts "Each array task gets its own ID through:\n\n"
          puts pastel.bold.green("$SLURM_ARRAY_TASK_ID\n")
          puts "Your script can use this ID to choose which file, row, or parameter to process.\n\n"
          puts pastel.bold("Examples:\n")
          puts "#{pastel.bold.bright_magenta('1-10')}       runs task IDs 1 through 10"
          puts "#{pastel.bold.bright_magenta('0-9')}        runs task IDs 0 through 9"
          puts "#{pastel.bold.bright_magenta('1,5,9')}      runs only task IDs 1, 5, and 9"
          puts "#{pastel.bold.bright_magenta('1-100%10')}   creates 100 tasks, but only runs 10 at the same time"
          puts "#{pastel.bold.bright_magenta('1-20:2')}     runs every 2nd task, e.g. 1, 3, 5 ... 19\n\n"
          puts "The #{pastel.bold('%')} part limits how many array tasks can run at once."
          puts "For example, #{pastel.bold('1-100%10')} means run at most 10 tasks at the same time.\n\n"
          puts "If you are unsure, start small, such as 1-5 or 1-10.\n\n"

          flags[key] = prompt.ask(pastel.bold.bright_magenta(question), default: flags[key] || DEFAULT_VALUES[key]) do |q|
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
          puts "\nA GPU (Graphics Processing Unit) is a special processor used for highly parallel work, such as machine learning, simulations, and some scientific workloads.\n"

          if max_gpus.positive?
            puts "\nThe maximum number of GPUs on partition #{pastel.bold(selected_partition[:name])} is #{pastel.bold(max_gpus)} per node.\n"
          else
            puts pastel.red("\nThis partition does not appear to have any GPUs.\n")
            exit(1)
          end

          puts

          flags[key] = prompt.ask(pastel.bold.blue(question), default: flags[key] || DEFAULT_VALUES[key] || 1) do |q|
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
          puts "For most beginner MPI jobs, each task is one copy of your MPI program running in parallel.\n\n"
          puts "For partition #{pastel.bold(selected_partition[:name])}, the rough maximum number of MPI tasks is #{max_ntasks}.\n\n"
          puts "This is based on #{node_count} nodes multiplied by #{max_cpu_cores} CPU cores per node.\n\n"

          flags[key] = prompt.ask(pastel.bold.yellow(question), default: flags[key] || DEFAULT_VALUES[key]) do |q|
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
        # Does the welcome logo animation
        # @param [Pastel::Delegator] pastel
        def animation(pastel)
          skipped = false

          # logo = <<~LOGO
          #         -=++++#{'                                                         '}
          #      :+++++++.#{'                                                         '}
          #    :++++++++:#{'                                                          '}
          #   :++++++++=#{'                                                           '}
          #   +++++++++:#{'                                                           '}
          #   +++++++++   .+++=#{'                                                    '}
          #   +++++++++- -++++:#{'                                                    '}
          #   -+++++++++++++++#{'                                                     '}
          #   -+++++++++++++++     -#{'                                               '}
          #    =++++++++++++++:  =++-#{'                                              '}
          #     :++++++++++++++-++++:#{'                                              '}
          #       =++++++++++++++++=#{'                                               '}
          #        :++++++++++++++++=                                      -+#{'      '}
          #          -=++++++++++++++-                              .     -+++#{'     '}
          #            :++++++++++++++=                     --     =+-    +++++#{'    '}
          #               -+++++++++++++-                  +++.   ++++   ++++++:#{'   '}
          #                  =++++++++++++-             --++++.-=+++++ -+++++++:#{'   '}
          #                     -++++++++++++-+++==++++++++++++++++++++++++++++#{'    '}
          #                        =++++++++++++++++++++++++++++++++++++++++++:#{'    '}
          #                          -++++++++++++++++++++++++++++++++++++++-#{'      '}
          #                            +++++++++++++=-+++++++++++++++++++=:#{'        '}
          #                               --+++++++++=        +----:=#{'              '}
          #                                    .=+++++#{'                             '}
          #                                        -+-#{'                             '}
          # LOGO

          # puts
          # logo.each_line do |line|
          #   if interrupted?
          #     $stdin.getch
          #     skipped = true
          #     system('clear')
          #     break
          #   end

          #   sleep(0.08)
          #   puts pastel.bold.cyan(line.rstrip)
          # end

          # return if skipped

          # sleep(1)
          # system('clear')

          # banner = <<~BANNER
          #    █████╗ ██╗      ██████╗███████╗███████╗
          #   ██╔══██╗██║     ██╔════╝██╔════╝██╔════╝
          #   ███████║██║     ██║     █████╗  ███████╗
          #   ██╔══██║██║     ██║     ██╔══╝  ╚════██║
          #   ██║  ██║███████╗╚██████╗███████╗███████║
          #   ╚═╝  ╚═╝╚══════╝ ╚═════╝╚══════╝╚══════╝

          #        ██╗ ██████╗ ██████╗
          #        ██║██╔═══██╗██╔══██╗
          #        ██║██║   ██║██████╔╝
          #   ██   ██║██║   ██║██╔══██╗
          #   ╚█████╔╝╚██████╔╝██████╔╝
          #    ╚════╝  ╚═════╝ ╚═════╝

          #   ██╗███╗   ██╗████████╗███████╗██████╗  █████╗  ██████╗████████╗██╗██╗   ██╗███████╗
          #   ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██║██║   ██║██╔════╝
          #   ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝███████║██║        ██║   ██║██║   ██║█████╗
          #   ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗██╔══██║██║        ██║   ██║╚██╗ ██╔╝██╔══╝
          #   ██║██║ ╚████║   ██║   ███████╗██║  ██║██║  ██║╚██████╗   ██║   ██║ ╚████╔╝ ███████╗
          #   ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝   ╚═╝   ╚═╝  ╚═══╝  ╚══════╝
          # BANNER

          # puts
          # banner.each_line do |line|
          #   if interrupted?
          #     $stdin.getch
          #     skipped = true
          #     system('clear')
          #     break
          #   end

          #   sleep(0.08)
          #   puts pastel.bold.cyan(line.rstrip)
          # end

          # return if skipped

          # sleep(0.2)
          # puts
          #
          #
          alces = <<~ALCES.chomp
             █████╗ ██╗      ██████╗███████╗███████╗
            ██╔══██╗██║     ██╔════╝██╔════╝██╔════╝
            ███████║██║     ██║     █████╗  ███████╗
            ██╔══██║██║     ██║     ██╔══╝  ╚════██║
            ██║  ██║███████╗╚██████╗███████╗███████║
            ╚═╝  ╚═╝╚══════╝ ╚═════╝╚══════╝╚══════╝
          ALCES

          job = <<~JOB.chomp
                 ██╗ ██████╗ ██████╗
                 ██║██╔═══██╗██╔══██╗
                 ██║██║   ██║██████╔╝
            ██   ██║██║   ██║██╔══██╗
            ╚█████╔╝╚██████╔╝██████╔╝
             ╚════╝  ╚═════╝ ╚═════╝
          JOB

          icon = <<~ICON.chomp
            'o`
            'ooo`
            `oooo`
             `oooo`         'o`
               `ooooo`  `ooooo
                  `oooo:oooo`
                     `v`
          ICON

          interactive = <<~INTERACTIVE.chomp
            ██╗███╗   ██╗████████╗███████╗██████╗  █████╗  ██████╗████████╗██╗██╗   ██╗███████╗
            ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██║██║   ██║██╔════╝
            ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝███████║██║        ██║   ██║██║   ██║█████╗
            ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗██╔══██║██║        ██║   ██║╚██╗ ██╔╝██╔══╝
            ██║██║ ╚████║   ██║   ███████╗██║  ██║██║  ██║╚██████╗   ██║   ██║ ╚████╔╝ ███████╗
            ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝   ╚═╝   ╚═╝  ╚═══╝  ╚══════╝
          INTERACTIVE

          job_lines = job.lines.map(&:chomp)
          icon_lines = icon.lines.map(&:chomp)

          top_height = [job_lines.length, icon_lines.length].max
          job_width = job_lines.map { |line| visible_length(line) }.max || 0

          job_and_icon = (0...top_height).map do |index|
            job_line = job_lines[index] || ''
            icon_line = icon_lines[index] || ''

            padding = job_width - visible_length(job_line) + 29

            job_line + (' ' * padding) + icon_line
          end.join("\n")

          banner = [
            '',
            alces,
            '',
            job_and_icon,
            '',
            interactive
          ].join("\n")

          puts

          banner.each_line do |line|
            if interrupted?
              $stdin.getch
              skipped = true
              system('clear')
              break
            end

            sleep(0.08)

            # Reapply cyan after any white sections reset the terminal colour.
            coloured_line = pastel.bold.cyan(line.rstrip)
            puts coloured_line
          end

          if skipped
            puts
            puts pastel.bold.cyan(banner)
          end

          sleep(0.2)
          puts
        end

        def visible_length(text)
          text.gsub(/\e\[[0-9;]*m/, '').length
        end

        def interrupted?
          $stdin.wait_readable(0)
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
            puts pastel.red("\nCould not find partition information for #{flags[:partition]}\n")
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
