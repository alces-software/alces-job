# frozen_string_literal: true

require 'tty-spinner'
require 'pastel'
require 'terminal-table'
require 'tty-box'
require 'time'

require_relative '../paths/paths'

module AlcesJob
  module Services
    module Tracking
      def self.load_job_status(job_id)
        path = Services::Paths.new.user_job_dir
        pastel = Pastel.new

        spinner = TTY::Spinner.new(
          '[:spinner] :title ...',
          success_mark: pastel.green('✓'),
          error_mark: pastel.red('✗')
        )

        puts
        spinner.update(title: 'Loading job data')
        spinner.auto_spin

        begin
          data = {}

          valid_keys = %w[
            jobId
            outputFile
            errorFile
            startTime
            endTime
            totalSteps
          ]

          valid_pattern = /stage(Start|End)[0-9]+/
          File.foreach(File.join(path, job_id)) do |line|
            key, value = line.strip.split(':', 2)

            unless valid_keys.include?(key) || valid_pattern.match(key)
              spinner.error(pastel.red('(Malformed status file)'))
              warn pastel.red("\nThe status file located at #{File.join(path, job_id)} was incorrectily formed and the data could not be parsed\n")
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
        ]

        necessary_keys.each do |key|
          next unless data[key].nil?

          spinner.error(pastel.red('(Malformed status file)'))
          warn pastel.red("\nThe status file located at #{File.join(path, job_id)} was incorrectily formed. It does not have all the necessary values\n")
          exit(1)
        end

        spinner.success(pastel.green('(Loaded)'))

        data
      end

      def self.generate_table(data, verbose)
        pastel = Pastel.new

        file_job_id = data['jobId']&.to_i
        output      = data['outputFile']
        error       = data['errorFile']
        start_time  = data['startTime']&.to_i
        end_time    = data['endTime'].to_s.empty? ? nil : data['endTime'].to_i
        total_steps = data['totalSteps']&.to_i

        completed_steps =
          (1..total_steps).count do |i|
            !data["stageEnd#{i}"].to_s.empty?
          end

        completed_steps = total_steps if end_time

        rows = [
          [pastel.cyan('Job ID'), file_job_id],
          [pastel.cyan('Output'), output],
          [pastel.cyan('Error'), error],
          [pastel.cyan('Started'), format_time(start_time)],
          [pastel.cyan('Progress'), "#{completed_steps}/#{total_steps} stages"]
        ]

        if verbose && total_steps.positive?
          rows << [pastel.cyan('Stages'), '']

          (1..total_steps).each do |i|
            stage_start_key = "stageStart#{i}"
            stage_end_key = "stageEnd#{i}"
            stage_start_time = data[stage_start_key]
            stage_end_time = data[stage_end_key]

            row_str = if stage_start_time
                        if stage_end_time
                          pastel.green("Completed after #{format_duration(stage_start_time, stage_end_time)}")
                        else
                          pastel.yellow("Running for #{format_duration(stage_start_time, Time.now.to_i)}")
                        end
                      else
                        pastel.yellow('Pending')
                      end
            rows << [
              pastel.cyan("  Stage #{i}"),
              row_str
            ]
          end
        end

        status =
          if end_time
            pastel.green('Completed')
          else
            pastel.yellow.bold('Pending')
          end

        elapsed_time = format_duration(start_time, end_time)

        rows << if end_time
                  [pastel.cyan('Total Time'), elapsed_time]
                else
                  [pastel.cyan('Time Elapsed'), elapsed_time]
                end
        rows << [pastel.cyan('Status'), status]

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

      def self.format_time(epoch)
        return nil unless epoch

        Time.at(epoch.to_i).strftime('%Y-%m-%d %H:%M:%S')
      end

      def self.format_duration(start_epoch, end_epoch = nil)
        return nil unless start_epoch

        start_time = Time.at(start_epoch.to_i)
        finish_time = end_epoch ? Time.at(end_epoch.to_i) : Time.now

        seconds = (finish_time - start_time).to_i

        format_seconds(seconds)
      end

      def self.format_seconds(total_seconds)
        minutes, seconds = total_seconds.divmod(60)
        hours, minutes = minutes.divmod(60)

        if hours.positive?
          format('%02dh %02dm %02ds', hours, minutes, seconds)
        elsif minutes.positive?
          format('%02dm %02ds', minutes, seconds)
        else
          format('%02ds', seconds)
        end
      end
    end
  end
end
