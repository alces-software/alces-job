# frozen_string_literal: true

require 'tty-prompt'
require 'terminal-table'
require 'pastel'

module AlcesJob
  module Services
    class InteractiveWizard
      def valid_slurm_time?(time_string, max_days = 7)
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
          days * 86_400 +
          hours * 3600 +
          minutes * 60 +
          seconds

        max_seconds = max_days * 86_400

        total_seconds <= max_seconds
      end

      def human_readable_time(max_time)
        days, time = max_time.split('-')
        hours, minutes, seconds = time.split(':')

        parts = []

        parts << "#{days.to_i} days" if days.to_i > 0
        parts << "#{hours.to_i} hours" if hours.to_i > 0
        parts << "#{minutes.to_i} minutes" if minutes.to_i > 0
        parts << "#{seconds.to_i} seconds" if seconds.to_i > 0

        parts.join(', ')
      end

      def valid_memory?(input, max_memory)
        requested_gb = memory_to_gb(input)
        max_gb = memory_to_gb(max_memory)

        return false if requested_gb.nil?
        return false if max_gb.nil?

        requested_gb <= max_gb
      end

      def memory_to_gb(memory)
        match = memory.to_s.strip.match(/\A(\d+(?:\.\d+)?)\s*(G|GB|T|TB|P|PB)\z/i)

        return nil unless match

        amount = match[1].to_f
        unit = match[2].upcase

        case unit
        when 'G', 'GB'
          amount
        when 'T', 'TB'
          amount * 1024
        when 'P', 'PB'
          amount * 1024 * 1024
        end
      end

      def call
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

        typesOfJob = ['serial (default)', 'mpi', 'gpu', 'array']

        ############ PARTITIONS SECTION ###############
        #
        partitionTypes = %w[gpu101 gpu800 gpu999]

        partition_rows = [
          ['gpu101', 'Idle', 4, 64, '1 TB', '7 days'],
          ['gpu800', 'Mixed', 8, 128, '2 TB', '2 days'],
          ['gpu999', 'Alloc', 2, 64, '512 GB', '12 hours']
        ]

        partition_table = Terminal::Table.new do |t|
          t.title = 'Available GPU Partitions'
          t.headings = [
            'Partition',
            'State',
            'Nodes',
            'CPUs/Node',
            'Memory/Node',
            'Max Runtime'
          ]
          t.rows = partition_rows
        end

        maxRunTime = '7-00:00:00'

        human_readable_max_time = human_readable_time(maxRunTime)

        availCpuCores = 64

        availMemory = '1 TB'

        prompt = TTY::Prompt.new

        job_type = prompt.select('What type of job would you like to run?', typesOfJob)

        question_bank = {
          serial: {
            job_name: 'What is your job name? (e.g. my slurm job)',
            partition: 'Which partition would you like to use?',
            time: 'How long would you like your job to run for?',
            nodes: 'How many nodes would you like to request?',
            cpus_per_task: 'How many CPU cores would you like to request?',
            mem: 'How much memory will your job use?',
            command: 'What command would you like to run?'
          },

          mpi: {
            job_name: 'What is your job name? (e.g. my slurm job)',
            partition: 'Which partition would you like to use?',
            time: 'How long would you like your job to run for?',
            nodes: 'How many nodes would you like to request?',
            ntasks: 'How many MPI tasks would you like per node?',
            cpus_per_task: 'How many CPU cores would each MPI task require?',
            mem: 'How much memory will your job use?',
            command: 'What MPI command would you like to run?'
          },

          gpu: {
            job_name: 'What is your job name? (e.g. my slurm job)',
            partition: 'Which partition would you like to use?',
            time: 'How long would you like your job to run for?',
            gres: 'How many GPUs would you like to request?',
            cpus_per_task: 'How many CPU cores would you like to request?',
            mem: 'How much memory will your job use?',
            command: 'What command would you like to run?'
          },

          array: {
            job_name: 'What is your job name? (e.g. my slurm job)',
            partition: 'Which partition would you like to use?',
            time: 'How long would you like your job to run for?',
            array: 'What array range would you like to use (e.g. 1-100)?',
            max_concurrent_tasks: 'What is the maximum number of array tasks that may run simultaneously?',
            mem: 'How much memory would you like per array task?',
            command: 'What command would you like to run?'
          }
        }

        job_type = job_type.split[0] if job_type.split.length > 1

        system('clear')
        wizard = self

        questions = question_bank[job_type.to_sym]
        result = prompt.collect do
          questions.each do |item, question|
            if item == :partition
              puts partition_table
              key(item).select(question, partitionTypes)

            # elsif item == :time
            #   puts "The max runtime for a job is: #{maxRunTime} i.e. #{human_readable_max_time}"
            #   key(item).ask(question)

            elsif item == :time
              puts "The max runtime for a job is: #{maxRunTime} i.e. #{human_readable_max_time}"

              key(item).ask(
                question
              ) do |q|
                q.validate ->(input) { wizard.valid_slurm_time?(input) }
                q.messages[:valid?] = 'Time must be in format D-HH:MM:SS and not exceed 7 days'
              end

            elsif item == :nodes
              puts 'Available nodes on this partition: 8'
              key(item).ask(question) do |q|
                q.validate(/\A\d+\z/)
                q.messages[:valid?] = 'Please enter a whole number'
                q.convert :int
              end

            elsif item == :tasks_per_node
              puts "Available CPU cores per node: #{availCpuCores}"
              puts 'For pure MPI, this is usually the number of MPI processes per node.'
              key(item).ask(question) do |q|
                q.validate(/\A\d+\z/)
                q.messages[:valid?] = 'Please enter a whole number'
                q.convert :int
              end

            elsif item == :cpus_per_task
              puts "Available CPUs on this partition: #{availCpuCores}"

              key(item).ask(question) do |q|
                q.validate(/\A\d+\z/)
                q.messages[:valid?] = 'Please enter a whole number'
                q.convert :int
              end

            elsif item == :mem
              puts "Available memory on this node is: #{availMemory}"
              key(item).ask(question) do |q|
                q.validate ->(input) { wizard.valid_memory?(input, availMemory) }
                q.messages[:valid?] = "Enter memory up to #{availMemory} (e.g. 500G, 1TB)"
              end

            elsif item == :gpus
              puts 'Available GPUs per node: 4'
              key(item).ask(question) do |q|
                q.validate(/\A\d+\z/)
                q.messages[:valid?] = 'Please enter a whole number'
                q.convert :int
              end

            elsif item == :array_range
              puts 'Examples: 1-10, 1-100, 1-1000'
              key(item).ask(question)

            elsif item == :max_concurrent_tasks
              puts 'Example: if your array range is 1-100 and you enter 10, only 10 tasks run at once.'
              key(item).ask(question) do |q|
                q.validate(/\A\d+\z/)
                q.messages[:valid?] = 'Please enter a whole number'
                q.convert :int
              end

            elsif item == :command
              puts 'Examples: python script.py, Rscript analysis.R, ./my_program, mpirun ./my_program'
              key(item).ask(question)

            else
              key(item).ask(question)
            end
            system('clear')
          end
        end

        puts "You enetered #{questions}"
        puts "Result is #{result}"
      end
    end
  end
end
