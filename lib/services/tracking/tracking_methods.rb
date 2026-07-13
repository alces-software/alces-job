# frozen_string_literal: true

require 'tty-spinner'
require 'pastel'
require 'terminal-table'
require 'tty-box'
require 'time'
require 'tty-prompt'

require_relative '../paths/paths'

module AlcesJob
  module Services
    module Tracking
      def self.load_job_status(job_id, silent: false)
        path = Services::Paths.new.user_job_dir
        pastel = Pastel.new

        spinner = TTY::Spinner.new(
          '[:spinner] :title ...',
          success_mark: pastel.green('✓'),
          error_mark: pastel.red('✗')
        )

        unless silent
          puts
          spinner.update(title: 'Loading job data')
          spinner.auto_spin
        end

        begin
          data = {}

          valid_keys = %w[
            jobId
            totalSteps
            outputFile
            errorFile
            startTime
            status
            endTime
            exitCode
          ]

          valid_pattern = /stage(Start|End|Status)[0-9]+/
          File.foreach(File.join(path, job_id)) do |line|
            key, value = line.strip.split(':', 2)

            unless valid_keys.include?(key) || valid_pattern.match(key)
              spinner.error(pastel.red('(Malformed status file)'))
              warn pastel.red("\nThe status file located at #{File.join(path, job_id)} was incorrectly formed and the data could not be parsed\n")
              exit(1)
            end

            data[key] = value
          end
        rescue Errno::ENOENT, Errno::ENOTDIR
          spinner.error(pastel.red('(Not found)'))
          warn pastel.red("\nJob with job id: #{job_id} couldn't be found\n")
          exit(1)
        end

        necessary_keys = %w[
          jobId
          outputFile
          errorFile
          startTime
          totalSteps
          status
        ]

        necessary_keys.each do |key|
          next unless data[key].nil?

          spinner.error(pastel.red('(Malformed status file)'))
          warn pastel.red("\nThe status file located at #{File.join(path, job_id)} was incorrectly formed. It does not have all the necessary values\n")
          exit(1)
        end

        spinner.success(pastel.green('(Loaded)')) unless silent

        data
      end

      def self.generate_table(data, verbose)
        pastel = Pastel.new

        file_job_id = data['jobId']&.to_i
        output = data['outputFile']
        error = data['errorFile']
        start_time = data['startTime']&.to_i
        status = data['status']
        end_time = data['endTime'].to_s.empty? ? nil : data['endTime'].to_i
        total_steps = data['totalSteps']&.to_i

        completed_steps =
          (1..total_steps).count do |i|
            data["stageStatus#{i}"] == 'completed'
          end

        completed_steps = total_steps if status == 'completed'

        rows = [
          [pastel.cyan('Job ID'), file_job_id],
          [pastel.cyan('Output'), output],
          [pastel.cyan('Error'), error],
          [pastel.cyan('Started'), format_time(start_time)],
          [pastel.cyan('Progress'), "#{completed_steps}/#{total_steps} Stages"]
        ]

        if verbose && total_steps.positive?
          rows << [pastel.cyan('Stages'), '']

          (1..total_steps).each do |i|
            stage_start_key = "stageStart#{i}"
            stage_end_key = "stageEnd#{i}"
            stage_status_key = "stageStatus#{i}"
            stage_start_time = data[stage_start_key]
            stage_end_time = data[stage_end_key]
            stage_status = data[stage_status_key]

            row_str = if stage_status
                        if stage_status == 'completed'
                          pastel.green("Completed after #{format_duration(stage_start_time, stage_end_time)}")
                        elsif status == 'failed'
                          pastel.red.bold("Failed after #{format_duration(stage_start_time, end_time)}")
                        else
                          pastel.yellow("Running for #{format_duration(stage_start_time, Time.now.to_i)}")
                        end
                      elsif status == 'failed'
                        pastel.bright_black('Cancelled')
                      else
                        pastel.yellow('Pending')
                      end
            rows << [
              pastel.cyan("  Stage #{i}"),
              row_str
            ]
          end
        end

        status_text =
          if status == 'running'
            pastel.yellow.bold('Pending')
          elsif status == 'completed'
            pastel.yellow.bold('Completed')
          else
            pastel.red.bold('Failed')
          end

        elapsed_time = format_duration(start_time, end_time)

        rows << if %w[running failed].include?(status)
                  [pastel.cyan('Total Time'), elapsed_time]
                else
                  [pastel.cyan('Time Elapsed'), elapsed_time]
                end
        rows << [pastel.cyan('Status'), status_text]

        Terminal::Table.new do |t|
          t.title = pastel.bold.white('SLURM Job')
          t.rows = rows
          t.align_column(1, :right)
          t.style = {
            border: :unicode,
            padding_left: 1,
            padding_right: 1
          }
        end
      end

      def self.get_job_history(status: nil, limit: nil)
        path = Services::Paths.new.user_job_dir

        jobs = Dir.children(path).map do |job|
          load_job_status(job, silent: true)
        end

        jobs = jobs.select do |job|
          next true unless status

          current_status = job['status'] == 'running' ? :running : :completed
          current_status == status
        end

        jobs = jobs.sort_by { |j| j['jobId'].to_i }
        jobs = jobs.first(limit.to_i) if limit

        jobs
      end

      def self.display_jobs(jobs)
        rows = jobs
          .map do |job|
            [job['jobId'], job_status(job)]
          end

        puts Terminal::Table.new(
          headings: ['Job ID', 'Status'],
          rows: rows,
          style: {
            border: :unicode,
            padding_left: 1,
            padding_right: 1
          }
        )
      end

      def self.display_jobs_interactive(jobs)
        prompt = TTY::Prompt.new

        choices = jobs.each_with_index.map do |job, index|
          {
            name: "#{job['jobId'].ljust(20)} #{job_status(job)}",
            value: index
          }
        end

        title = TTY::Box.frame(
          width: 50,
          height: 3,
          align: :center,
          padding: 0
        ) do
          'Select a Job'
        end

        loop do
          system('clear')

          puts title

          index = prompt.select('Choose a job:', choices)

          system('clear')
          puts generate_table(jobs[index], true)
          key = prompt.keypress('[Press any key to continue, or q to quit]')
          exit(0) if key == 'q'
        end
      end

      def self.inject_tracking(options)
        return unless options[:track]

        pastel = Pastel.new

        spec = Gem.loaded_specs['alces-job']
        unless spec
          warn pastel.red("\nCould not locate gem environment. Are you sure you have installed the gem?\n")
          exit(1)
        end
        lib_path = File.join(spec.full_gem_path, 'lib/helper_functions/functions.bash')
        job_path = Services::Paths.new.user_job_dir
        options[:tracking_path] = lib_path
        options[:job_path] = job_path
      end

      def self.job_status(job)
        pastel = Pastel.new
        job['status'] == 'running' ? pastel.yellow('RUNNING') : pastel.green('COMPLETED')
      end

      def self.format_time(epoch)
        return nil unless epoch

        Time.at(epoch.to_i).strftime('%Y-%m-%d %H:%M:%S')
      end

      # Formats the duration
      # @param [Integer] start_epoch
      # @param [Integer | nil] end_epoch
      # @return [String]
      def self.format_duration(start_epoch, end_epoch = nil)
        return nil unless start_epoch

        start_time = Time.at(start_epoch.to_i)
        finish_time = end_epoch ? Time.at(end_epoch.to_i) : Time.now

        seconds = (finish_time - start_time).to_i

        format_seconds(seconds)
      end

      # Formats the seconds for displaying
      # @param [Integer] total_seconds
      # @return [String]
      def self.format_seconds(total_seconds)
        minutes, seconds = total_seconds.divmod(60)
        hours, minutes = minutes.divmod(60)

        if hours.positive?
          format('%<h>02dh %<m>02dm %<s>02ds', h: hours, m: minutes, s: seconds)
        elsif minutes.positive?
          format('%<m>02dm %<s>02ds', m: minutes, s: seconds)
        else
          format('%<s>02ds', s: seconds)
        end
      end
    end
  end
end
