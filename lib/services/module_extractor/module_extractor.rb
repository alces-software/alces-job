# frozen_string_literal: true

module AlcesJob
  module Services
    # Takes in the options and combines all the module options into one
    # @param [Hash] argv
    # @return [hash]
    def self.module_extractor(argv)
      modules = []

      argv.each_with_index do |arg, index|
        value =
          if ['--module', '-m'].include?(arg)
            argv[index + 1]
          elsif arg.start_with?('--module=', '-m=')
            arg.split('=', 2).last
          end

        next unless value

        value
          .split(',')
          .map(&:strip)
          .reject(&:empty?)
          .each { |mod| modules << mod }
      end

      modules
    end
  end
end
