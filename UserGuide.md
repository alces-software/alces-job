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

- `alces-job completion`
  - Installs shell tab completion for `alces-job` so commands and flags can be completed interactively.

- `alces-job version` (`-v`, `--version`)
  - Prints the installed version and the ASCII banner.

- `alces-job interactive` (`-i`, `--interactive`)
  - Launches the guided wizard for selecting a job type, resources, modules, and output settings.

- `alces-job generate universal|serial|mpi|gpu|array`
  - Creates a Slurm job script from a selected template.
  - Common flags:
    - `--job_name`, `-J` — sets the Slurm job name.
    - `--mem` — requests memory such as `4G` or `2000M`.
    - `--time`, `-t` — sets the walltime limit.
    - `--partition`, `-p` — chooses the Slurm partition or queue.
    - `--module`, `-m` — loads one or more environment modules.
    - `--workdir` — runs the job from the specified working directory.
    - `--command` — sets the shell command that the script executes.
    - `--account`, `-A` — charges the job to the specified Slurm account.
    - `--output_file`, `-o` — writes the generated script to a file.
    - `--error`, `-e` — sets the standard error output path.
    - `--mail_user` — sends job notifications to an email address.
    - `--mail_type` — chooses when mail notifications are sent.
    - `--submit` — submits the generated job to Slurm immediately.
    - `--yes` — skips confirmation prompts when submitting.
    - `--profile` — loads defaults from a saved profile.
    - `--site_config` — uses site or admin configuration values.
    - `--dry_run` — previews generation without saving the script.
    - `--track` — injects tracking helpers into the script.
    - `--edit` — opens the generated script in your editor before saving.
    - `--prepare` — creates a dedicated working directory and standard output/error paths.
    - `--local_scratch` — runs the job from local scratch and copies results back.
    - `--scratch_path` — overrides the local scratch directory.
    - `--template` — uses a custom or alternate template.
  - Template-specific flags:
    - `universal`: `--nodes`, `--ntasks`, `--cpus_per_task`, `--gres`, `--array`, `--dependency`
    - `serial`: `--mem`, `--time`, `--partition`, `--module`, `--workdir`, `--command`
    - `mpi`: `--nodes`, `--ntasks`, `--cpus_per_task`
    - `gpu`: `--nodes`, `--ntasks`, `--cpus_per_task`, `--gres`
    - `array`: `--nodes`, `--array`, `--dependency`

- `alces-job modify <script>`
  - Updates an existing Slurm script in place using the provided flags.
  - Flags:
    - `--job_name`, `-J` — changes the job name shown in Slurm.
    - `--nodes`, `-N` — requests a specific number of compute nodes.
    - `--ntasks`, `-n` — sets the total number of tasks.
    - `--cpus_per_task`, `-c` — sets the CPU cores assigned to each task.
    - `--mem` — updates the memory request.
    - `--time`, `-t` — changes the walltime limit.
    - `--partition`, `-p` — selects a new Slurm partition.
    - `--account`, `-A` — changes the Slurm account to charge.
    - `--gres` — requests generic resources such as GPUs.
    - `--output` — writes the script output to a specific file path.
    - `--error`, `-e` — changes the standard error path.
    - `--mail_user` — sets the notification email address.
    - `--mail_type` — chooses when email notifications are sent.
    - `--array` — sets a Slurm array specification.
    - `--dependency` — adds a job dependency rule.
    - `--module`, `-m` — loads additional modules.
    - `--workdir` — changes the working directory used by the job.
    - `--command` — replaces the command executed by the script.
    - `--output_file`, `-o` — writes the modified script to a new file.
    - `--submit` — submits the modified script to Slurm.
    - `--yes` — skips confirmation prompts when submitting.

- `alces-job modify remove <script>`
  - Removes selected Slurm directives from an existing script.
  - Flags:
    - `--job_name`, `-J` — removes the job-name directive.
    - `--nodes`, `-N` — removes the nodes directive.
    - `--ntasks`, `-n` — removes the ntasks directive.
    - `--cpus_per_task` — removes the cpus-per-task directive.
    - `--mem` — removes the memory request.
    - `--time`, `-t` — removes the time limit.
    - `--partition`, `-p` — removes the partition directive.
    - `--account`, `-A` — removes the account directive.
    - `--gres` — removes the generic resource directive.
    - `--output` — removes the stdout file directive.
    - `--error`, `-e` — removes the stderr file directive.
    - `--mail_user` — removes the mail-user directive.
    - `--mail_type` — removes the mail-type directive.
    - `--array` — removes the array directive.
    - `--dependency` — removes the dependency directive.
    - `--output_file`, `-o` — writes the result to a new file instead of overwriting the original.
    - `--submit` — submits the modified script after removal.

- `alces-job config init`
  - Generates an initial configuration file for user or admin defaults.
  - Flags:
    - `--job_name`, `-J` — stores a default Slurm job name.
    - `--mem` — stores a default memory requirement.
    - `--time`, `-t` — stores a default walltime limit.
    - `--partition`, `-p` — stores a default partition.
    - `--module`, `-m` — stores default modules.
    - `--workdir` — stores a default working directory.
    - `--command` — stores a default command to run.
    - `--account`, `-A` — stores a default Slurm account.
    - `--output_file`, `-o` — stores a default output script filename.
    - `--error`, `-e` — stores a default error file path.
    - `--mail_user` — stores a default notification email.
    - `--mail_type` — stores a default mail notification type.
    - `--submit` — stores the default submit behavior.
    - `--editor` — stores a default editor for manual script editing.

- `alces-job template list`
  - Lists templates from built-in, admin, and user locations.

- `alces-job template show --name <template>`
  - Displays the contents of a named template so you can review or reuse it.

- `alces-job validate script <path>`
  - Validates an existing Slurm script file and reports any problems.

- `alces-job validate template <name>`
  - Validates a custom template by name.

- `alces-job module list`
  - Lists available modules on the system.
  - Flags:
    - `--show_description`, `-d` — displays each module description.
    - `--show_full_name`, `-f` — shows the full module name used for loading.
    - `--hide_categories`, `-h` — hides category headings in the output.

- `alces-job module search`
  - Searches available modules by name, version, or category.
  - Flags:
    - `--module_name`, `-n` — filters by the module name.
    - `--version`, `-v` — filters by module version.
    - `--category`, `-c` — filters by module category.
    - `--show_description`, `-d` — displays each module description.
    - `--show_full_name`, `-f` — shows the full module name used for loading.
    - `--hide_categories`, `-h` — hides category headings in the output.

- `alces-job profile list`
  - Lists saved user profiles.

- `alces-job profile show --profile <name>`
  - Shows the contents of a saved profile.

- `alces-job profile create --profile_name <name> [flags]`
  - Saves a reusable set of Slurm defaults.
  - Flags are the same as those used for script generation and include job name, resources, modules, workdir, command, array, and dependency options.

- `alces-job profile delete --profile <name>`
  - Deletes a saved profile.

- `alces-job profile edit change --profile_name <name> [flags]`
  - Changes or adds values inside an existing profile.
  - Flags mirror `profile create` and update only the options you provide.

- `alces-job profile edit remove --profile_name <name> [flags]`
  - Removes stored values from an existing profile.
  - Use boolean flags for each field to clear that setting from the profile.

- `alces-job sysinfo init`
  - Creates a local cache of system information used by other commands.

- `alces-job sysinfo update`
  - Refreshes the stored system information.
  - Flags:
    - `--partition`, `-p` — updates partition information.
    - `--package`, `-k` — updates package information.
    - `--all`, `-a` — updates all available information.

- `alces-job status <jobId> [flags]`
  - Gets the status of a tracked job.
  - Flags:
    - `--verbose`, `-v` — shows detailed stage information.
    - `--live` — refreshes the status display in real time.

- `alces-job history [flags]`
  - Shows a history of tracked jobs.
  - Flags:
    - `--status` — filters by job status (`running` or `completed`).
    - `--limit` — limits how many jobs are shown.
    - `--interactive`, `-i` — lets you select a job and view its full details.

- `alces-job tracking [flags]`
  - Prints the paths needed to manually source the tracking helper functions.
  - Flags:
    - `--pretty`, `-p` — formats the output in a more readable way.