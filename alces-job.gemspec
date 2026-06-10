# frozen_string_literal: true

require_relative 'lib/alces_job/version'

Gem::Specification.new do |spec|
  spec.name          = 'alces-job'
  spec.version       = AlcesJob::VERSION

  spec.summary       = 'Generate Slurm job scripts from templates'
  spec.description   = spec.summary
  spec.homepage      = AlcesJob::GITHUB_URL
  spec.executables   = ['alces-job']
  spec.bindir        = 'bin'
  spec.authors       = ['Oscar Thomson', 'Alex Wood', 'Calum Murphy', 'Arun Bhatti']
  spec.email         = [
    'oscar.thomson@alces-software.com',
    'alexander.wood@alces-software.com',
    'calum.murphy@alces-software.com',
    'arun.bhatti@alces-software.com'
  ]

  spec.files = Dir.chdir(__dir__) do
    Dir[
      'lib/**/*',
      'bin/*',
      'templates/*'
    ]
  end

  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.3'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
