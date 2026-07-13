# frozen_string_literal: true

module AlcesJob
  module Services
    class LocalScratch
      def self.helper(scratch_path: '/tmp')
        scratch_path ||= '/tmp'

        <<~BASH
          alces_setup_local_scratch() {
            if [ "${SLURM_JOB_NUM_NODES:-1}" -gt 1 ]; then
              echo "Local scratch is only supported for single-node jobs." >&2
              exit 1
            fi

            scratch_dir="#{scratch_path}/$USER/${SLURM_JOB_NAME}-${SLURM_JOB_ID}"
            result_dir="$HOME/${SLURM_JOB_NAME}-${SLURM_JOB_ID}"

            mkdir -p "$scratch_dir"
            mkdir -p "$result_dir"

            cp -a "$SLURM_SUBMIT_DIR"/. "$scratch_dir"/

            cd "$scratch_dir" || exit 1
          }

          alces_copy_results_back() {
            exit_status=$?

            cp -a "$scratch_dir"/. "$result_dir"/
            rm -rf "$scratch_dir"

            return "$exit_status"
          }

          alces_cleanup() {
            local exit_status=$?

            alces_copy_results_back

            if command -v alces_end_job >/dev/null 2>&1; then
              alces_end_job "$exit_status"
            fi

            exit "$exit_status"
          }
          alces_setup_local_scratch
          trap alces_copy_results_back EXIT
        BASH
      end
    end
  end
end
