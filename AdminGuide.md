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

## System config

`alces-job` uses two kinds of YAML config files:

1. The shipped package config at `config/config.yaml`.
   - This is part of the installation and tells the CLI where site files live.
   - It contains keys like `admin_config_file`, `system_info_file`, and `admin_templates_folder`.
2. The admin defaults file, usually `/etc/alces-job/config.yaml`.
   - This file contains actual site defaults that are merged into job generation.

### What the package config controls

The package config file `config/config.yaml` defines where the CLI looks for site-wide resources:

- `admin_config_file` — path to the admin defaults file.
- `system_info_file` — path where system information is saved.
- `admin_templates_folder` — folder for system-wide templates.
- `user_profile_dir` — location under each user home for profile files.

### What the admin config file contains

The admin config file is a plain YAML map of default CLI options.
It is loaded by generate commands when `--site_config` is enabled (default behavior).

Typical admin defaults include:

- `partition`
- `account`
- `mem`
- `time`
- `gres`
- `output`
- `error`
- `mail_user`
- `mail_type`
- `module`
- `workdir`
- `command`
- `array`
- `dependency`

Example admin defaults file:

```yaml
partition: work
account: research
mem: 8G
time: 04:00:00
gres: gpu:1
mail_user: admin@example.com
mail_type: END,FAIL
module:
  - gcc/12
  - openmpi/4.1
workdir: /home/%USER%
```

You can also use the admin config to define template defaults, notification behavior, and site-wide modules that should load for every generated script.

### How admin defaults are applied

For supported generate commands (`generate universal`, `generate serial`, `generate mpi`, `generate gpu`, `generate array`):

- the command loads `config/config.yaml` from the package to find the actual admin config file path
- if `--site_config` is true and the admin defaults file exists, it loads the admin defaults
- those defaults are merged with the CLI options provided by the user
- user-supplied CLI options take precedence over admin defaults
- the tool prints a warning when a CLI flag overwrites a value defined by the admin config

If the admin config file does not exist, generation proceeds using only the command-line options and any profile values.

### Creating the admin config file

Use the built-in init command to create the admin defaults file with minimal values:

```sh
$ sudo alces-job config init --partition work --account research
```

This command writes the provided keys into the admin defaults file at the path configured by `config/config.yaml`.

You can edit `/etc/alces-job/config.yaml` manually to add more defaults later.

### Notes

- The admin config file is not the same as the shipped package config under `config/config.yaml`.
- The admin config file contains actual option defaults for script generation, not package settings.
- If you want to bypass admin defaults for a specific generate command, use `--site_config false`.

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
