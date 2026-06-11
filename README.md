# alces-job
![CI](https://github.com/alces-software/alces-job/actions/workflows/ci.yml/badge.svg)

alces-job is a command-line tool that helps users quickly generate high-quality, ready-to-submit Slurm job scripts using templates, parameters, profiles, and site-specific defaults.

## Installation

### Method 1

Ensure gem is installed by running

```sh
$ gem --version
```

Go to the [releases](https://github.com/alces-software/alces-job/releases) page and download the gem file, or download it directly with

```sh
$ wget https://github.com/alces-software/alces-job/archive/refs/tags/v0.3.0.gem
```

Run:

```sh
$ gem install alces-job-0.3.0.gem
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
$ gem install alces-job-0.3.0.gem
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

Use these flags together to customize the generated Slurm script and optionally submit it automatically.

### Interactive

The tool has an interactive wizard that can be accessed by using the `-i` or `--interactive` flag on the base command

```sh
$ alces-job --interactive
```

### Templates

The generated Slurm script is produced from an ERB template in the `templates/` directory.

By default the base command renders `templates/default.erb`, and the CLI passes the command options into the template as `@context` values. For example, `--job-name`, `--nodes`, `--command`, and other flags are available inside the template as `<%= @context.job_name %>`, `<%= @context.nodes %>`, and `<%= @context.command %>`.

Specialized commands such as `mpi`, `gpu`, and `array` select a different template by name before rendering, so they can generate job scripts with the right SBATCH boilerplate for that workload.

If you want to customize output, add a new ERB file to `~/.alces-job/templates` and render it by passing the matching template name into the command via the template command
