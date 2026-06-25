# User Guide

## Installation

Ensure ruby is installed with

```
$ ruby --version

$ gem --version
```

If it is not, install ruby.

### Installing Ruby

#### Debian and Ubuntu
```
$ sudo apt update
$ sudo apt install ruby-full build-essential ruby-dev
```
#### Fedora, Rocky Linux, AlmaLinux, RHEL, and CentOS Stream
```
$ sudo dnf groupinstall "Development Tools"
$ sudo dnf install ruby ruby-devel
```
#### openSUSE Leap and Tumbleweed
```
$ sudo zypper install -t pattern devel_basis
$ sudo zypper install ruby ruby-devel
```
#### Arch Linux
```
$ sudo pacman -S ruby base-devel
```
#### Alpine Linux
```
$ sudo apk add ruby ruby-dev build-base
```
#### Verify the Installation
```
$ ruby --version
$ gem --version
```

### Installing alces-job

Go to the [releases](https://github.com/alces-software/alces-job/releases) page and download the gem file, or download it directly with

```sh
$ wget https://github.com/alces-software/alces-job/releases/download/v0.5.0/alces-job-0.5.0.gem
```

Run:

```sh
$ gem install alces-job-0.5.0.gem
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

For an example of a template, look inside `/templates`

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