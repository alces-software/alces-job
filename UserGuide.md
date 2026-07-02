# User Guide

## Installation

Ensure ruby 4 is installed with

```
$ ruby --version

$ gem --version
```

If it is not, install ruby.

### Install Ruby 4

#### Debian / Ubuntu
```sh
$ sudo apt update
$ sudo apt install -y ruby-full
```
Note: Debian and Ubuntu will install the default Ruby version in their repositories. Ruby 4 will only be installed if your release includes it.

#### Fedora
```sh
$ sudo dnf install -y ruby
```
Fedora may provide Ruby 4 in newer releases. If available, this package will install it automatically.

#### RHEL / AlmaLinux / Rocky Linux / CentOS Stream

Check if Ruby 4 is available as a module:

```sh
$ sudo dnf module list ruby
```

If a Ruby 4 stream exists:

```sh
$ sudo dnf module reset ruby -y
$ sudo dnf module enable ruby:4.0 -y
$ sudo dnf install -y ruby ruby-devel
```

If no Ruby 4 module is available, your distribution does not currently support Ruby 4 via system packages.

#### openSUSE
```sh
$ sudo zypper install -y ruby
```

#### Arch Linux

```sh
$ sudo pacman -S --noconfirm ruby
```

Arch typically provides the latest stable Ruby version available at the time of release.

#### Alpine Linux
```sh
$ sudo apk add ruby
```
### Verify installation
```sh
ruby --version
gem --version
```

Confirm that the output shows Ruby 4.x.

### Ruby Version Manager

If you cannot install ruby 4 via your native package manager, install it via a version manager such as [mise](https://mise.jdx.dev/getting-started.html).

### Installing alces-job

Go to the [releases](https://github.com/alces-software/alces-job/releases) page and download the gem file, or download it directly with

```sh
$ wget https://github.com/alces-software/alces-job/releases/download/v1.0.1/alces-job-1.0.1.gem
```

Run:

```sh
$ gem install alces-job-1.0.1.gem
```

Verify installation with

```sh
$ alces-job version
```

## Features

### Generating a Script
`alces-job generate` creates a portable Slurm sbatch job script for HPC systems. You can define core resources (CPU, memory, time), set the job name, and specify the command to run. It can either generate a script for review or submit it directly.

Example:
```sh
$ alces-job generate universal \
  --job_name my_job \
  --nodes 1 \
  --ntasks 4 \
  --time 01:00:00 \
  --partition short \
  --mem 8G \
  --command "python run.py" \
  --output output_%j.log \
  --submit
```

### Interactive Wizard
The cli tool comes with an interactive wizard that will take you through the steps of creating an sbatch job script. This is reccommended for new users or anyone not experienced with SLURM.

```sh
$ alces-job -i
```

### Modifying an Existing Script
`alces-job modify` will let you change the directives for an existing sbatch file if you need to modify something on the fly

```sh
$ alces-job modify myjob.sbatch --job_name myjob --nodes 2 --time 01:00:00 --command "python main.py" --submit
```

### Validating an Existing Script
`alces-job validate` will tell you if the given sbatch file has valid values

```sh
$ alces-job validate script myjob.sbatch
```
### Templates
Templates are how the tool generates the sbatch scripts. They use embedded Ruby (ERB-style placeholders like <%= @context... %>) to dynamically fill in job settings such as job name, array range, partition, memory, modules, working directory, and the command to run.

When you run alces-job generate universal, the tool takes values you pass via flags (like --job_name, --array, --command, etc.) and injects them into this template to produce a ready-to-submit sbatch script.

Conditional blocks (like <% if @context.mem -%>) mean sections are only included if you provide those options, keeping the final script clean and tailored to your job.

For an example of a template, look inside [/templates](https://github.com/alces-software/alces-job/tree/main/templates) on the repo.

#### Where you would put your own template

You would typically save your custom template as a file on disk, for example:

~/.config/alces-job/templates/my_slurm_template.erb

Then pass it to the command using the --template flag:

```sh
$ alces-job generate universal \
  --job_name test_job \
  --array 1-10 \
  --time 01:00:00 \
  --mem 4G \
  --command "python run.py" \
  --template my_slurm_template
```

The tool will:

Read your template from ~/.config/alces-job/templates/my_slurm_template.erb

Replace all <%= @context.* %> placeholders with your provided values

Output a final sbatch script (and optionally submit it if --submit is used)

### Profiles
Profiles are saved collections of job settings that let you reuse common Slurm configurations without retyping flags every time.

Instead of specifying things like --nodes, --mem, or --time for each job, you store them once in a named profile (e.g. fast, gpu, longrun) and then reuse or edit them as needed.

When you run a job with a profile, its stored values are applied automatically, and you can still override them with command-line flags if needed.

#### Create a profile
You define a reusable set of defaults:

```sh
$ alces-job profile create \
  --profile_name fast \
  --job_name fastjob \
  --nodes 1 \
  --ntasks 4 \
  --mem 4G \
  --time 01:00:00
```

This saves a profile called fast containing those job settings.

#### Use or inspect a profile
To view what a profile contains:

```sh
$ alces-job profile show --profile fast
```

This prints the stored configuration so you can verify or reuse it.

#### Update a profile
You can modify existing values:

```sh
$ alces-job profile edit change \
  --profile_name fast \
  --mem 8G \
  --time 02:00:00
```

This updates only the specified fields, leaving everything else unchanged.

#### Remove settings from a profile

To unset specific values entirely:

```sh
$ alces-job profile edit remove \
  --profile_name fast \
  --mem \
  --time
```

Those flags are deleted from the profile, so future jobs won’t inherit them.

#### Delete a profile

If you no longer need it:

```sh
$ alces-job profile delete --profile fast
```

### Inspecting a job

Creating a job with the `--track` flag will allow the tool to be able to track the progress of the job script. It will automatically inject the `alces_start_job` helper function that tells the tool when the script has started.
If your script has multiple distinct sections, they can be wrapped with the `alces_start_stage` and `alces_end_stage` helper functions so this information can also be tracked. Make sure to set the number of stages in the `ALCES_TOTAL_STAGES` environment variable.

To view the status of a tracked script run

```sh
$ alces-job status <jobId>
```

This will show information about how far the job has progressed and if it has completed. More information about the stages can be displayed with the `--verbose -v` flag.

`--live` will show a table with information that updates in real time.

#### Manual Sourcing
If you want to add tracking to a preexisting file, or you just want to manually source the functions yourself, the locations of the function definitions and the directory that the tracking information is stored can be found by running

```sh
$ alces-job tracking
```

#### Config Options

The directory that the tracking information is stored in can be specified in either the user or admin config files in `tracking.path`

#### History

The history of tracked jobs can be accessed with
```sh
$ alces-job history
```
This will show a list of recent jobs. The amount of jobs it shows can be capped with the `--limit` flag, and the results can be filtered with the `--status` flag.
These can be combined with the `--interactive -i` flag, which will let you select one of the options and view the full details about it.

## All Commands

- `alces-job version` (`-v`, `--version`)
  - Prints the installed version and ASCII banner.

- `alces-job interactive` (`-i`, `--interactive`)
  - Starts the interactive wizard for generating or editing scripts.

- `alces-job modify <script>`
  - Modifies an existing sbatch/Slurm script using the provided flags.
  - Flags:
    - `--job_name`, `-j`
    - `--nodes`, `-N`
    - `--ntasks`, `-n`
    - `--cpus_per_task`, `-c`
    - `--mem`
    - `--time`, `-t`
    - `--partition`, `-p`
    - `--account`, `-A`
    - `--gres`
    - `--output`
    - `--error`, `-e`
    - `--mail_user`
    - `--mail_type`
    - `--array`
    - `--dependency`
    - `--module`
    - `--workdir`
    - `--command`
    - `--output_file`, `-o`
    - `--submit`

- `alces-job modify remove <script>`
  - Removes directives from an existing sbatch/Slurm script using the provided flags.
  - Flags:
    - `--job_name`, `-j`
    - `--nodes`, `-N`
    - `--ntasks`, `-n`
    - `--cpus_per_task`, `-c`
    - `--mem`
    - `--time`, `-t`
    - `--partition`, `-p`
    - `--account`, `-A`
    - `--gres`
    - `--output`
    - `--error`, `-e`
    - `--mail_user`
    - `--mail_type`
    - `--array`
    - `--dependency`
    - `--module`
    - `--workdir`
    - `--command`
    - `--output_file`, `-o`
    - `--submit`
- `alces-job generate universal`
  - Creates a universal sbatch script.
  - Flags:
    - `--job_name`, `-J`
    - `--nodes`, `-N`
    - `--ntasks`, `-n`
    - `--cpus_per_task`, `-c`
    - `--mem`
    - `--time`, `-t`
    - `--partition`, `-p`
    - `--account`, `-A`
    - `--gres`
    - `--output`
    - `--error`, `-e`
    - `--mail_user`
    - `--mail_type`
    - `--module`
    - `--workdir`
    - `--command`
    - `--array`
    - `--dependency`
    - `--output_file`, `-o`
    - `--submit`
    - `--yes`
    - `--template`
    - `--profile`
    - `--site_config`
    - `--dry_run`

- `alces-job generate serial`
  - Creates a serial sbatch script.
  - Flags:
    - `--job_name`, `-J`
    - `--mem`
    - `--time`, `-t`
    - `--partition`, `-p`
    - `--module`
    - `--workdir`
    - `--command`
    - `--output_file`
    - `--submit`
    - `--profile`
    - `--site_config`
    - `--yes`
    - `--dry_run`

- `alces-job generate mpi`
  - Creates an MPI sbatch script.
  - Flags:
    - `--job_name`, `-J`
    - `--nodes`, `-N`
    - `--ntasks`, `-n`
    - `--cpus_per_task`, `-c`
    - `--mem`
    - `--time`, `-t`
    - `--partition`, `-p`
    - `--module`
    - `--workdir`
    - `--command`
    - `--output_file`, `-o`
    - `--submit`
    - `--site_config`
    - `--yes`
    - `--profile`
    - `--dry_run`

- `alces-job generate gpu`
  - Creates a GPU sbatch script.
  - Flags:
    - `--job_name`, `-J`
    - `--nodes`, `-N`
    - `--ntasks`, `-n`
    - `--cpus_per_task`, `-c`
    - `--mem`
    - `--time`, `-t`
    - `--partition`, `-p`
    - `--gres`
    - `--module`
    - `--workdir`
    - `--command`
    - `--output_file`, `-o`
    - `--submit`
    - `--site_config`
    - `--yes`
    - `--profile`
    - `--dry_run`

- `alces-job generate array`
  - Creates an array sbatch script.
  - Flags:
    - `--job_name`, `-J`
    - `--nodes`, `-N`
    - `--mem`
    - `--time`, `-t`
    - `--partition`, `-p`
    - `--module`
    - `--workdir`
    - `--command`
    - `--array`
    - `--dependency`
    - `--output_file`
    - `--submit`
    - `--site_config`
    - `--yes`
    - `--profile`
    - `--dry_run`

- `alces-job config init`
  - Generates the initial admin config file.
  - Flags:
    - `--partition`
    - `--account`

- `alces-job template list`
  - Lists available templates from built-in, admin, and user locations.

- `alces-job template show --name <template>`
  - Displays the contents of a named template.

- `alces-job validate script <path>`
  - Validates an existing sbatch script file.

- `alces-job validate template <name>`
  - Validates a custom template by name.

- `alces-job profile list`
  - Lists saved user profiles.

- `alces-job profile show --profile <name>`
  - Shows the contents of a saved profile.

- `alces-job profile create --profile_name <name> [flags]`
  - Creates a profile from the provided flags.
  - Flags mirror script generation flags, including job name, resources, notifications, modules, workdir, command, array, and dependency.

- `alces-job profile delete --profile <name>`
  - Deletes a saved profile.

- `alces-job profile edit change --profile_name <name> [flags]`
  - Changes or adds flags within an existing profile.
  - Flags mirror `profile create`.

- `alces-job profile edit remove --profile_name <name> [flags]`
  - Removes stored flags from a profile.
  - Use boolean flags for each field to remove.

- `alces-job status <jobId> [flags]`
  - Gets the status of a job
  - Flags:
    - `--verbose -v`
    - `--live`

- `alces-job history [flags]`
  - Gets a history of the jobs
  - Flags:
    - `--status`
    - `--limit`
    - `--interactive -i`

- `alces-job tracking [flags]`
  - Gets the location of the tracking functions so they can be manually sourced
  - Flags:
    - `--pretty`