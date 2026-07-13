# frozen_string_literal: true

module AlcesJob
  module Services
    class Prepare
      def self.directives
        ''
      end

      def self.helper
        <<~BASH
          alces_prepare_job() {
            job_dir="$HOME/${SLURM_JOB_NAME}-${SLURM_JOB_ID}"

            if [ -n "$SLURM_ARRAY_TASK_ID" ]; then
              job_dir="${job_dir}-${SLURM_ARRAY_TASK_ID}"
            fi

            mkdir -p "$job_dir"
            cd "$job_dir" || exit 1

            exec > "${job_dir}/${SLURM_JOB_NAME}-${SLURM_JOB_ID}.out"
            exec 2> "${job_dir}/${SLURM_JOB_NAME}-${SLURM_JOB_ID}.err"
          }

          alces_prepare_job
        BASH
      end
    end
  end
end
