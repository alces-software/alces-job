# frozen_string_literal: true

require 'dry/cli'

module Dry
  class CLI
    module Banner
      def self.extended_command_options(command)
        result = command.options.map do |option|
          name = Inflector.dasherize(option.name)

          name = if option.boolean?
                   "[no-]#{name}"
                 elsif option.flag?
                   name
                 elsif option.array?
                   "#{name}=VALUE1,VALUE2,.."
                 else
                   "#{name}=VALUE"
                 end

          if option.aliases.any?
            alias_names = option.alias_names.join(', ')
            name = "#{name}, #{alias_names}"
          end

          description = option.desc.to_s
          description += ", default: #{option.default.inspect}" unless option.default.nil?

          formatted_name = "  --#{name}"
          formatted_description = wrap(description, width: 72, indent: '      ')

          [formatted_name, "      # #{formatted_description}"].join("\n")
        end

        result << "  --help, -h\n      # Print this help"
        result.join("\n")
      end

      def self.build_subcommands_list(subcommands)
        subcommands.map do |subcommand_name, subcommand|
          description = subcommand.command.description.to_s
          wrapped_description = wrap(description, width: 72, indent: '      ')

          "  #{subcommand_name}\n      # #{wrapped_description}"
        end.join("\n")
      end

      def self.wrap(text, width: 72, indent: '      ')
        words = text.split(' ')
        return text if words.empty?

        lines = []
        current_line = words.shift

        words.each do |word|
          if current_line.length + word.length + 1 <= width
            current_line += " #{word}"
          else
            lines << current_line
            current_line = word
          end
        end

        lines << current_line
        lines.map.with_index do |line, index|
          index.zero? ? line : "#{indent}#{line}"
        end.join("\n")
      end
    end

    module Usage
      def self.show_all_options?
        ARGV.include?('help') && ARGV.include?('all')
      end

      def self.call(result)
        header = 'Commands:'

        commands(result).map do |name, node|
          next if node.hidden

          banner = "  #{command_name(result, name)}#{args_for(node)}"
          description = description(node.command) if node.leaf?

          output = if description
                     wrapped_description = Banner.wrap(description, width: 72, indent: '      ')
                     "#{banner}\n      # #{wrapped_description}"
                   else
                     banner
                   end

          # Add options for leaf commands only if "help all" is requested
          if show_all_options? && node.leaf? && node.command.options.any?
            options_output = format_options_for_command(node.command)
            output += "\n#{options_output}"
          end

          output
        end.compact.unshift(header).join("\n")
      end

      def self.format_options_for_command(command)
        options = command.options.map do |option|
          name = Inflector.dasherize(option.name)

          name = if option.boolean?
                   "[no-]#{name}"
                 elsif option.flag?
                   name
                 elsif option.array?
                   "#{name}=VALUE1,VALUE2,.."
                 else
                   "#{name}=VALUE"
                 end

          if option.aliases.any?
            alias_names = option.alias_names.join(', ')
            name = "#{name}, #{alias_names}"
          end

          description = option.desc.to_s
          description += ", default: #{option.default.inspect}" unless option.default.nil?

          formatted_name = "    --#{name}"
          formatted_description = Banner.wrap(description, width: 70, indent: '        ')

          [formatted_name, "        # #{formatted_description}"].join("\n")
        end

        options << "    --help, -h\n        # Print this help"
        "    Options:\n#{options.join("\n")}"
      end

      def self.args_for(node)
        if node.command && node.leaf? && node.children?
          ROOT_COMMAND_WITH_SUBCOMMANDS_BANNER
        elsif node.leaf?
          arguments(node.command)
        else
          SUBCOMMAND_BANNER
        end
      end

      def self.description(command)
        return unless CLI.command?(command)

        command.description unless command.description.nil?
      end

      def self.commands(result)
        result.children.sort_by { |name, _| name }
      end

      def self.command_name(result, name)
        ProgramName.call([result.names, name])
      end
    end
  end
end
