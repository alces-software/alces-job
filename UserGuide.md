# User Guide

## Installation

Ensure ruby is installed with

```
$ ruby --version`

$ gem --version`
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

## Commands

The `alces-job` CLI provides several commands and subcommands for generating, modifying, validating, and managing Slurm job scripts, templates, system info, and profiles.

### Available commands

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

- `alces-job sysinfo init`
  - Generates the initial system info file.
  - No flags.

- `alces-job sysinfo update`
  - Updates stored system information.
  - Flags:
    - `--node`, `-n`
    - `--partition`
    - `--package`
    - `--gpu`, `-g`
    - `--all`

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

### Examples

- Show version:
  ```sh
  $ alces-job version
  ```

- Start the interactive wizard:
  ```sh
  $ alces-job interactive
  ```

- Modify an existing script:
  ```sh
  $ alces-job modify myjob.sbatch --job_name myjob --nodes 2 --time 01:00:00 --command "python main.py" --submit
  ```

- Generate a universal script:
  ```sh
  $ alces-job generate universal --job_name myjob --nodes 1 --ntasks 4 --cpus_per_task 2 --mem 8G --time 02:00:00 --command "./run.sh" --output_file myjob.sbatch
  ```

- Generate a serial script:
  ```sh
  $ alces-job generate serial --job_name myserial --mem 2G --time 00:30:00 --command "python script.py" --yes
  ```

- Generate an MPI script:
  ```sh
  $ alces-job generate mpi --job_name mympi --nodes 2 --ntasks 16 --cpus_per_task 2 --time 04:00:00 --command "mpirun ./app"
  ```

- Generate a GPU script:
  ```sh
  $ alces-job generate gpu --job_name mygpu --nodes 1 --gres gpu:1 --mem 16G --time 03:00:00 --command "python gpu_train.py"
  ```

- Generate an array script:
  ```sh
  $ alces-job generate array --job_name myarray --nodes 1 --mem 4G --time 01:00:00 --array "1-10" --command "./run_task.sh"
  ```

- Initialize admin config:
  ```sh
  $ sudo alces-job config init --partition default --account research
  ```

- Initialize system info:
  ```sh
  $ sudo alces-job sysinfo init
  ```

- Update system info for GPUs and partitions only:
  ```sh
  $ alces-job sysinfo update --gpu --partition
  ```

- List available templates:
  ```sh
  $ alces-job template list
  ```

- Show a named template:
  ```sh
  $ alces-job template show --name default
  ```

- Validate an sbatch script:
  ```sh
  $ alces-job validate script myjob.sbatch
  ```

- Validate a custom template:
  ```sh
  $ alces-job validate template my_template
  ```

- Create a profile:
  ```sh
  $ alces-job profile create --profile_name fast --job_name fastjob --nodes 1 --ntasks 4 --mem 4G --time 01:00:00
  ```

- Show a profile:
  ```sh
  $ alces-job profile show --profile fast
  ```

- Delete a profile:
  ```sh
  $ alces-job profile delete --profile fast
  ```

- Change profile flags:
  ```sh
  $ alces-job profile edit change --profile_name fast --mem 8G --time 02:00:00
  ```

- Remove flags from a profile:
  ```sh
  $ alces-job profile edit remove --profile_name fast --mem --time
  ```

