# frozen_string_literal: true

require_relative 'lib/alces_job/version'

Gem::Specification.new do |spec|
  spec.name          = 'alces-job'
  spec.version       = AlcesJob::VERSION

  spec.summary       = 'Generate Slurm job scripts from templates'
  spec.description   = 'alces-job is a small CLI tool for generating Slurm sbatch scripts from templates, profiles, and site defaults.'

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

  spec.required_ruby_version = '>= 4.0'

  spec.add_dependency 'dry-cli', '~> 1.4'
  spec.add_dependency 'dry-cli-completion', '~> 2.0 '
  spec.add_dependency 'pastel', '~> 0.8.0'
  spec.add_dependency 'terminal-table', '~> 4.0'
  spec.add_dependency 'tty-box', '~> 0.7.0'
  spec.add_dependency 'tty-prompt', '~> 0.23.1'
  spec.add_dependency 'tty-spinner', '~> 0.9.3'
  spec.add_dependency 'unicode-display_width', '~> 2.6'
  spec.add_dependency 'xdg', '~> 10.2'

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.post_install_message = <<~MSG
    Thanks for installing Alces-Job!

    To enable or update tab completion, run one of the following:

      Global installation:
        sudo alces-job completion

      User-specific installation:
        alces-job completion
  MSG
end
