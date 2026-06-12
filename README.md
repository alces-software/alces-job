# alces-job
alces-job is a command-line tool that helps users quickly generate high-quality, ready-to-submit Slurm job scripts using templates, parameters, profiles, and site-specific defaults.

## Installation

### Method 1

Ensure gem is installed by running

```sh
$ gem --version
```

Go to the [releases](https://github.com/alces-software/alces-job/releases) page and download the gem file, or download it directly with

```sh
$ wget https://github.com/alces-software/alces-job/archive/refs/tags/v0.5.0.gem
```

Run:

```sh
$ gem install alces-job-0.5.0.gem
```

Verify installation with

```sh
$ alces-job version
```

### Method 2: Build from source

Ensure gem is installed by running

```sh
$ gem --version
```

Run:

```sh
$ git clone https://github.com/alces-software/alces-job
$ cd alces-job
```

Build the gem with

```sh
$ gem build alces-job.gemspec
```

Install it with:

```sh
$ gem install alces-job-0.5.0.gem
```

Verify installation with

```sh
$ alces-job version
```

## Usage

The basic utility of the command can be run with

```sh
$ alces-job base [OPTIONS]
```

This will generate an output file, by default called `job.sbatch`, with any SBATCH options provided.

### Default command options

The default command supports the following flags:

- `--job-name NAME`
  - Sets the Slurm job name (`#SBATCH --job-name=NAME`).
- `--nodes N`
  - Sets the number of cluster nodes to request.
- `--ntasks N`
  - Sets the total number of tasks for the job.
- `--cpus-per-task N`
  - Sets the number of CPU cores to allocate per task.
- `--mem SIZE`
  - Sets the amount of memory requested (e.g. `4G`, `2000M`).
- `--time DURATION`
  - Sets the walltime limit for the job (e.g. `02:00:00`).
- `--partition PARTITION`
  - Sets the Slurm partition/queue to submit to.
- `--account ACCOUNT`
  - Sets the Slurm account to charge.
- `--gres GRES`
  - Sets generic resources like GPUs (`gpu:1`, `gpu:2`).
- `--output PATH`
  - Sets the job output file path (`#SBATCH --output=PATH`).
- `--error PATH`
  - Sets the job error file path (`#SBATCH --error=PATH`).
- `--mail-user ADDRESS`
  - Sets the email address for Slurm notifications.
- `--mail-type TYPE`
  - Sets the Slurm mail notification type (`BEGIN`, `END`, `FAIL`, etc.).
- `--module NAME`
  - Loads one or more environment modules before running the job.
- `--workdir PATH`
  - Changes to the specified working directory inside the job script.
- `--command COMMAND`
  - The shell command to run inside the generated job script.
- `--array ARRAY_SPEC`
  - Sets the Slurm array specification (`#SBATCH --array=...`).
- `--dependency DEPENDENCY`
  - Sets the Slurm job dependency string (`#SBATCH --dependency=...`).
- `--output-file PATH`
  - Writes the generated script to a specific filename instead of `job.sbatch`.
- `--submit`
  - If present, submits the generated script to Slurm with `sbatch` after generation.
- `--dry-run`
  - If present, does not save the file, and instead outputs what would be saved to the console

Use these flags together to customize the generated Slurm script and optionally submit it automatically.

### Interactive

The tool has an interactive wizard that can be accessed by using the `-i` or `--interactive` flag on the base command

```sh
$ alces-job --interactive
```

### Templates

The generated Slurm script is produced from an ERB template in the `templates/` directory.

By default the base command renders `templates/default.erb`, and the CLI passes the command options into the template as `@context` values. For example, `--job-name`, `--nodes`, `--command`, and other flags are available inside the template as `<%= @context.job_name %>`, `<%= @context.nodes %>`, and `<%= @context.command %>`.

Specialized commands such as `mpi`, `gpu`, and `array` select a different template by name before rendering so they can generate job scripts with the correct SBATCH boilerplate for that workload.

Custom templates can be added by creating a new ERB file in `.alces-job/templates` following the example of one given in `./templates`. You can then call these templates by using the `--template` flag and specifying the name

System-wide templated can be created in a simelar manner, by creating an ERB file in `/etc/alces-job/templates/`. These templates can be called by any user, but are overwritten by their own ones.

List all the available templates to use
```sh
$ alces-job template list
```
Output the contents of the template to the console
```sh
$ alces-job template show TEMPLATE
```

## Command examples

Generate a basic job script:

```sh
$ alces-job base --job-name test-job --nodes 1 --ntasks 1 --cpus-per-task 2 --mem 4G --time 01:00:00 --command 'echo hello'
```

Generate a GPU job script:

```sh
$ alces-job gpu --job-name gpu-job --nodes 1 --ntasks 1 --cpus-per-task 4 --mem 16G --gres gpu:1 --time 02:00:00 --command 'python train.py'
```

Generate an MPI job script:

```sh
$ alces-job mpi --job-name mpi-job --nodes 2 --ntasks 32 --cpus-per-task 2 --mem 8G --time 04:00:00 --command 'mpirun ./app'
```

Generate an array job script:

```sh
$ alces-job array --job-name array-job --nodes 1 --mem 2G --time 01:00:00 --array '1-10%2' --command 'echo task $SLURM_ARRAY_TASK_ID'
```

Generate a serial job via a template:

```sh
$ alces-job base --job-name serial-job --mem 1G --time 01:00:00 --template serial
```

Use the interactive mode to answer prompts instead of supplying flags manually:

```sh
$ alces-job interactive
```

Show help for any supported command:

```sh
$ alces-job --help
$ alces-job base --help
```

## Development workflow

To work on this project locally:

1. Install dependencies:

```sh
$ bundle install
```

2. Run tests:

```sh
$ bundle exec rspec
```

3. Run the default Rake task:

```sh
$ bundle exec rake
```

4. Run style checks:

```sh
$ bundle exec rubocop
```

5. Build the gem locally:

```sh
$ gem build alces-job.gemspec
```

6. Run the CLI from source:

```sh
$ bundle exec ruby bin/alces-job base --help
```

## Architecture and internals

The project is structured around a simple CLI registry and a generator service:

- `bin/alces-job` is the executable entrypoint.
- `lib/cli/cli.rb` defines the `AlcesJob::CLI` registry and loads all commands.
- Command classes live in `lib/cli/commands/` and register themselves with Dry::CLI.
  - `base`, `gpu`, `mpi`, `array`, `config init`, `config update`, `interactive`, and `version`
- `lib/services/generator.rb` is responsible for rendering templates, saving the generated script, and submitting it to Slurm.
- Templates live in `templates/` and are selected by command-specific logic.
  - `default.erb` is used for the base command.
  - `gpu.erb`, `mpi.erb`, and `array.erb` are used by their respective commands.
- The generator converts CLI options into `@context` using `OpenStruct`, making options available inside ERB templates.
- `lib/services/sysinfo/` and `lib/services/interactive_wizard.rb` support interactive mode and config generation.

### How a command runs

1. CLI loads `bin/alces-job`.
2. `lib/cli/cli.rb` loads the command classes.
3. The selected command class builds the options hash.
4. The command creates `AlcesJob::Services::Generator` with those options.
5. The generator renders the chosen ERB template and writes it to disk.
6. If `--submit` is set, the generator calls `sbatch` on the generated file.

