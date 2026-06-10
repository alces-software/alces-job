module IntegerDirectiveValidator

    def self.validate(sbatch_lines, errors)
        integer_directives = ["--ntasks=", "--cpus-per-task=", "--nodes="]
        integer_directives.each do |directive|
            line = sbatch_lines.find {|sbatch_line| sbatch_line.include?("#{directive}")}
            next unless line

            value = line.split(directive).last.strip

            unless value.match?(/\A[1-9]\d*\z/)
                errors << "Invalid format for #{directive.chomp('=')}: #{value}. Expected a positive integer value."
            end
        end
    end
end
