# frozen_string_literal: true

require_relative 'lib/alces_job/version'

Gem::Specification.new do |spec|
  spec.name          = 'alces-job'
  spec.version       = AlcesJob::VERSION

  spec.summary       = 'Generate Slurm job scripts from templates'
  spec.description   = spec.summary
  spec.homepage      = AlcesJob::GITHUB_URL
  spec.executables   = ['alcesjob']
  spec.bindir        = 'bin'
  spec.authors       = %w[Oscar Alex Calum Arun]
  spec.email         = ['you@example.com']

  spec.files = Dir.chdir(__dir__) do
    Dir[
      'lib/**/*',
      'bin/*',
      'templates/*'
    ]
  end

  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.3'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
