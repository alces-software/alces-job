require_relative "converters/memory_converter"

require_relative "converters/time_converter"

require_relative "validators/integer_directive_validator"

require_relative "validators/sbatch_directive_validator"

errors = []


maxmem = 10

lines = File.readlines("/Users/ab/Documents/alces-job/scratch/valid_basic.slurm", chomp: true)

puts "File contents:"

puts lines

if lines[0] != "#!/bin/bash"    #Checking shebang

  errors << "Missing shebang, spelt incorrectly, or unsupported. Expected: #!/bin/bash."

end

sbatch_lines = lines.select { |line| line.start_with?("#SBATCH") }

if sbatch_lines.empty?

  errors << "No #SBATCH directives found."

end

directive_names = sbatch_lines.map do |line|    #Extracting directive names for duplicate checking
    line.split[1]&.split("=")&.first
end
duplicate = directive_names
    .compact
    .select {|name| directive_names.count(name) > 1 }
    .uniq

duplicate.each do |duplicate|
    errors << "Duplicate directive found: #{duplicate}."
end

SbatchDirectiveValidator.validate_directives(sbatch_lines, errors)    #Validating directives against the list of valid directives
IntegerDirectiveValidator.validate(sbatch_lines, errors)    #Validating integer directives





if sbatch_lines.any? { |line| line.include?("--mem=") }    #Checking memory directive


end

mem_line = sbatch_lines.find { |line| line.include?("--mem=") } #Finding the memory directive line
if mem_line #Checking the logic of my memory line 

    mem_value = mem_line.split("--mem=").last.strip
    requested_memory_mb = MemoryConverter.to_mb(mem_value)
    max_memory_mb = 5000    #dummy max memory value for validation

    if requested_memory_mb.nil?

        errors << "Invalid memory format: #{mem_value}. Expected formats like 4G, 500M, etc."

    elsif requested_memory_mb > max_memory_mb

        errors << "Requested memory (#{requested_memory_mb} MB) exceeds the maximum allowed (#{max_memory_mb} MB)."

    end

else

    warning << "No --mem directive found."

end



time_line = sbatch_lines.find { |line| line.include?("--time=") } #Finding the time directive line
max_time_seconds = 86400    #dummy max time which is one day in seconds

if time_line #Checking the logic of time line

    time_value = time_line.split("--time=").last.strip
    requested_time_seconds = TimeConverter.to_seconds(time_value)

    if requested_time_seconds.nil?
        errors << "Invalid time format. Expected HH:MM:SS or D-HH:MM:SS."
        elsif requested_time_seconds > max_time_seconds
        errors << "Requested time (#{requested_time_seconds} seconds) exceeds the maximum allowed (#{max_time_seconds} seconds)."
    end
else
    
    warning << "No --time directive found."

end

if errors.empty?

  puts "Validation passed."

else

  puts "Validation failed:"

  errors.each { |error| puts "- #{error}" }

end