# frozen_string_literal: true

require 'erb'
require 'ostruct'
require 'tempfile'

require_relative 'slurm_script_validator'

class TemplateValidator
    attr_reader :errors, :warnings
DEFAULT_CONTEXT = {
  job_name: 'template_test',
  nodes: 1,
  ntasks: 1,
  cpus_per_task: 1,
  mem: '4GB',
  time: '01:00:00',
  modules: [],
  command: 'echo "Hello, World!"'
}.freeze

  def initialize(template_path, context = {})

    @template_path = template_path

    @context = OpenStruct.new(DEFAULT_CONTEXT.merge(context))

    @errors = []

    @warnings = []

  end

  def validate?

    validate_template_file

    return false unless errors.empty?

    render_template

    errors.empty?

  end

  private

  def validate_template_file

    unless File.exist?(@template_path)

      errors << "Template not found: #{@template_path}"

      return

    end

    return if File.extname(@template_path) == '.erb'

    errors << 'Template must be an .erb file.'

  end

  def render_template

    template_content = File.read(@template_path)

    ERB.new(template_content, trim_mode: '-').result(binding)

  rescue StandardError => e

    errors << "Template failed to render: #{e.message}"

  end

end