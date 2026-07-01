# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'terminal-table'
require 'tty-box'
require 'time'

require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class Status < Dry::CLI::Command
        AlcesJob::CLI.register 'status', self

        argument :job_id, required: true, desc: 'The ID of the job'

        desc 'Get the status of jobs'

        def call(job_id:, **)
          pastel = Pastel.new
          path = Services::Paths.new.user_job_dir
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

            File.foreach(File.join(path, job_id)) do |line|
              key, value = line.strip.split(':', 2)
              data[key] = value
            end

            file_job_id = data['jobId']&.to_i
            output      = data['outputFile']
            error       = data['errorFile']
            start_time  = data['startTime']&.to_i
            end_time    = data['endTime'].to_s.empty? ? nil : data['endTime'].to_i

            spinner.success(pastel.green('(Loaded)'))

            rows = [
              [pastel.cyan('Job ID'), file_job_id],
              [pastel.cyan('Output'), output],
              [pastel.cyan('Error'), error],
              [pastel.cyan('Started'), format_time(start_time)]
            ]

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

            table = Terminal::Table.new do |t|
              t.title = pastel.bold.white('SLURM Job')
              t.rows = rows
              t.align_column(1, :right)
              t.style = {
                border: :unicode,
                padding_left: 1,
                padding_right: 1
              }
            end

            puts table
          rescue Errno::ENOENT, Errno::ENOTDIR
            spinner.error(pastel.red('(Not found)'))
            warn pastel.red("\nJob with job id: #{job_id} couldn't be found\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Unexpected errors
          # ------------------------------------------------------------
        rescue StandardError => e
          warn pastel.red("\nAn unexpected error occurred while running the command.")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end

        def format_time(epoch)
          return nil unless epoch

          Time.at(epoch.to_i).strftime('%Y-%m-%d %H:%M:%S')
        end

        def format_duration(start_epoch, end_epoch = nil)
          return nil unless start_epoch

          start_time = Time.at(start_epoch.to_i)
          finish_time = end_epoch ? Time.at(end_epoch.to_i) : Time.now

          seconds = (finish_time - start_time).to_i

          format_seconds(seconds)
        end

        def format_seconds(total_seconds)
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
end
