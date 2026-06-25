# Admin Guide

## Installing as root

Install the gem as root so system-wide config and templates are available to all users:

```sh
$ sudo gem install alces-job-0.5.0.gem
```

If you are installing from source, build and install as root:

```sh
$ sudo gem build alces-job.gemspec
$ sudo gem install alces-job-0.5.0.gem
```

### NOTE
This will install the gem system wide, but running the command with `sudo` will not work as ruby is in the wrong environments. To make any changes to system configs, the program must be run as the root user, or with `sudo -E env "PATH=$PATH"`, which will preserve the environment variables. Optionally, the program can be run with `sudo` directly, such as `sudo /usr/local/bin/alces-job`

## System config

The config can be initialised by running
```sh
$ alces-job config init [OPTIONS]
```
This will create a config file at `.config/alces-job/config.yaml` if run as a user or `/etc/alces-job/admin-config.yaml` if run as root

### What the admin config file contains

The admin config file is a plain YAML map of default CLI options.

It is loaded by generate commands when `--site_config` is enabled (default behavior).


Typical admin defaults include:

- nodes
- array
- ntasks
- cpus_per_task
- gres
- dependency
- job_name
- mem
- time
- partition
- module
- workdir
- command
- account
- output_file
- error
- mail_user
- mail_type
- submit

Example admin config file:

```yaml
values:
   partition:
      default: gpu1
      warn: false
   mem:
      default: 4G
      warn: true
```

### How admin defaults are applied

For supported generate commands (`generate universal`, `generate serial`, `generate mpi`, `generate gpu`, `generate array`):

- if `--site_config` is true and the admin defaults file exists, it loads the admin defaults and the user defaults and merges them
- those defaults are merged with the CLI options provided by the user
- user-supplied CLI options take precedence over admin defaults
- the tool prints a warning when a CLI flag overwrites a value defined by the admin config

If the admin config file does not exist, generation proceeds using only the command-line options and any profile values.

## Templates

System-wide templates should be placed in `/etc/alces-job/templates/`.

Built-in templates are located in the package `templates/` folder, but admins can provide site-specific versions in `/etc/alces-job/templates/`.

Users can add custom templates in their home directory under `~/.alces-job/templates/`.

### Template precedence

- User templates in `~/.alces-job/templates/`
- Admin templates in `/etc/alces-job/templates/`
- Built-in templates in `templates/`

### Using templates

To list available templates:

```sh
$ alces-job template list
```

To show a template's contents:

```sh
$ alces-job template show --name TEMPLATE_NAME
```

To generate a script from a specific template:

```sh
$ alces-job generate universal --template TEMPLATE_NAME --job_name example --command "./run.sh"
```

## System info

Admins should initialize system info once using:

```sh
$ sudo alces-job sysinfo init
```

Update system info later with:

```sh
$ alces-job sysinfo update --all
```

## Notes

- Installing as root ensures the CLI and admin templates are available system-wide.
- Regular users should not need elevated privileges to generate scripts or use their own templates.
- Keep admin templates and config under `/etc/alces-job/` for consistent site behavior.
