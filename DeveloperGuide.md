# Developer Guide

## Clone the repository

```sh
git clone git@github.com:alces-software/alces-job.git
cd alces-job
```

If you prefer HTTPS:

```sh
git clone https://github.com/alces-software/alces-job.git
cd alces-job
```

## Repository structure

- `bin/`
  - `alces-job` — executable CLI entrypoint script.
- `config/`
  - `config.yaml` — default site configuration used by the CLI and generator. Stores paths to relevent files.
- `lib/`
  - `cli/cli.rb` — registers commands with `dry-cli`.
  - `cli/commands/` — command definitions for generate, interactive, profile, config, sysinfo, template, validate, modify, version.
  - `services/` — business logic for script generation, interactive wizard, config conversion, validation, and system info.
  - `version.rb` — gem version constant.
- `spec/` — RSpec tests covering CLI behavior, generators, validators, and helpers.
- `templates/` — built-in ERB templates for supported Slurm job types.
- `.github/workflows/` — GitHub Actions workflows for CI and release automation.
- `alces-job.gemspec` — gem metadata and dependencies.

## How key functionality works

### CLI entrypoint and command registration

The executable `bin/alces-job` loads `lib/cli/cli.rb`.

`lib/cli/cli.rb` uses `dry-cli` to register a command registry and then requires all command files.

Each command in `lib/cli/commands/` is a `Dry::CLI::Command`. Example:
- `lib/cli/commands/version.rb` registers `version` with aliases `-v` and `--version`
- `lib/cli/commands/interactive.rb` registers `interactive`
- `lib/cli/commands/generate.rb` registers `generate universal`

### Script generation flow

The generator workflow is primarily implemented in:
- `lib/cli/commands/generate/universal.rb`
- `lib/services/script_generator/script_generator.rb`

When the user runs a generate command, the CLI command:
- reads `config/config.yaml`
- optionally merges in the admin config from `admin_config_file`
- optionally loads a user profile from `~/.alces-job/profiles/`
- creates `Services::ScriptGenerator` with the final options
- writes the generated script to disk
- optionally submits it to Slurm using `sbatch`

The actual template content is loaded from one of:
- user templates: `~/.alces-job/templates/*.erb`
- admin templates: path set by `admin_templates_folder` in `config/config.yaml`
- built-in templates: `templates/*.erb`

The generator supports a `--template` option to choose the template name.

### Supported job types

Built-in job generation types include:
- `serial` — single-node CPU job
- `mpi` — distributed MPI job
- `gpu` — GPU-accelerated workload
- `array` — array job generation
- `universal` — generic script generation using common Slurm options

The interactive wizard also exposes these job types and helps construct options from system information.

### Interactive wizard

`lib/services/interactive_wizard.rb` implements interactive mode.

It loads cluster metadata from the `system_info_file` path in `config/config.yaml` and falls back to a prompt-driven configuration if Slurm environment data is unavailable.

The wizard uses:
- `TTY::Prompt` for interactive questions
- `Terminal::Table` for displaying available job types
- `Pastel` for colored output

### Profiles and site configuration

Profiles are YAML files stored in the user's home directory under `~/.alces-job/profiles/`.

The generator command can load a profile via `--profile <name>`.

The site admin can provide a global config file at the location configured by `config/config.yaml` under `admin_config_file`.

If `--site-config` is enabled, the site config values are merged into generated options and warnings are printed when user flags overwrite admin-defined keys.

### Template and validation commands

- `lib/cli/commands/template/list.rb` and `lib/cli/commands/template/show.rb` expose template inspection commands.
- `lib/cli/commands/validate/` contains validator commands for Slurm scripts and template syntax.

## Development workflow

### Setup

Install dependencies with Bundler:

```sh
bundle install
```

Use Ruby 3.3 as specified by `alces-job.gemspec`.

### Run tests

Run the full test suite:

```sh
bundle exec rspec
```

### Run linting locally

```sh
bundle exec rubocop
```

### Run the CLI locally

```sh
bundle exec ruby bin/alces-job --help
```

Generate a script with a dry run:

```sh
bundle exec ruby bin/alces-job generate universal --job_name test-job --command "./run.sh" --dry_run
```

### Build the gem locally

```sh
gem build alces-job.gemspec
```

## GitHub Actions

### `.github/workflows/rspec.yml`

This workflow runs on pull requests and manual dispatch.

Jobs:
- `lint` — checks out the repository, sets up Ruby 3.3, installs dependencies, and runs `bundle exec rubocop`
- `test` — depends on `lint`, checks out the repository again, sets up Ruby 3.3, installs dependencies, and runs `bundle exec rspec`

The purpose is to ensure code style and tests pass before merging.

### `.github/workflows/release.yml`

This workflow runs when a GitHub release is published.

Jobs:
- `build` — checks out the repository, sets up Ruby 3.3, builds the gem with `gem build alces-job.gemspec`, and uploads the resulting `*.gem` file to the release using `softprops/action-gh-release@v2`.

## Notes for contributors

- Keep command implementations small and declarative in `lib/cli/commands/`
- Keep business logic inside `lib/services/`
- Use the built-in templates in `templates/` as examples for ERB-based script generation
- Keep unit tests in `spec/` and run `bundle exec rspec` before opening pull requests

## Extending templates

To add a new job template, create an ERB file and place it in one of the template locations (priority order):

- `~/.alces-job/templates/<name>.erb` (user templates)
- admin templates directory defined by `admin_templates_folder` in `config/config.yaml` (e.g. `/etc/alces-job/templates/`)
- built-in templates in the repository: `templates/<name>.erb`

Templates are evaluated by `Services::ScriptGenerator` with an OpenStruct `@context` containing the CLI options passed to the generator. Use `@context` to access flags set by the user or profile. Example minimal template:

```erb
#!/bin/sh
## SBATCH --job-name=<%= @context.job_name %>
## SBATCH --time=<%= @context.time %>

cd <%= @context.workdir || Dir.pwd %>
<%= @context.command %>
```

When creating templates:
- Follow existing built-in templates in `templates/` for style and comments.
- Keep templates idempotent and avoid side effects; let the CLI handle file writing and submission.
- Add a `template/show` and `template/list` test if the template behaviour needs verification.

## Adding a new CLI command

To add a new top-level command, create a file under `lib/cli/commands/`, implement a `Dry::CLI::Command`, and register it with the CLI registry. Then require the file from `lib/cli/cli.rb` (or follow the existing `require_relative` pattern).

Skeleton example (add to `lib/cli/commands/` as `my_command.rb`):

```ruby
# frozen_string_literal: true

require 'dry/cli'

module AlcesJob
  module CLI
    module Commands
      class MyCommand < Dry::CLI::Command
        AlcesJob::CLI.register 'my-command', self
        desc 'Short description of my command'

        option :example, type: :string, desc: 'Example option'

        def call(**options)
          # implement behaviour, call services in `lib/services/`
          puts "Running my command with #{options.inspect}"
        end
      end
    end
  end
end
```

After adding the file:
- Add a `require_relative 'commands/my_command'` line in `lib/cli/cli.rb` (to match repository style).
- Add unit tests under `spec/` to cover the new command's behaviour.
- Run `bundle exec rubocop` and `bundle exec rspec`.

If you want to add a subcommand under an existing namespace (for example `generate`), place the file in `lib/cli/commands/generate/` and register with the appropriate name (or rely on the parent files that require subcommands).