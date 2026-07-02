module AlcesJob
  module Services
    class NewDummyValidator
      attr_reader :errors, :warnings

      def initialize(file_path, system_info: SysInfo.load_info)
        @file_path = file_path
        @errors = []
        @warnings = []
        @system_info = system_info
      end

      def validate?
        lines = File.readlines(@file_path, chomp: true)
        validate_if_script_has_z(lines)
        errors.empty?
      end

      private

      def validate_if_script_has_z(lines)
        return unless lines.any? { |line| line.include?('z') }

        warnings << "The script contains the letter 'z', which is not allowed."
      end
    end
  end
end
