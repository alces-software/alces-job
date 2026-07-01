# frozen_string_literal: true

module AlcesJob
  module Services
    class Prepare
      def self.directives
        "#SBATCH --output=%x-%j.out\n#SBATCH --error=%x-%j.err\n"
      end

      def self.helper
        "alces_prepare_job() {\n  " \
          "job_dir=\"$HOME/${SLURM_JOB_NAME}-${SLURM_JOB_ID}\"\n" \
          "\n  " \
          "if [ -n \"$SLURM_ARRAY_TASK_ID\" ]; then\n    " \
          "job_dir=\"${job_dir}-${SLURM_ARRAY_TASK_ID}\"\n  " \
          "fi\n" \
          "\n  " \
          "mkdir -p \"$job_dir\"\n  " \
          "cd \"$job_dir\" || exit 1\n" \
          "}\n" \
          "\n" \
          "alces_prepare_job\n"
      end
    end
  end
end
