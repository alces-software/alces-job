# alces-job

`alces-job` is a small CLI tool for generating Slurm sbatch scripts from templates, profiles, and site defaults.

## Installation

Download the released gem and install it:

```sh
$ wget https://github.com/alces-software/alces-job/releases/download/v1.0.1/alces-job-1.0.1.gem
$ gem install alces-job-1.0.1.gem
```

Verify installation:

```sh
$ alces-job version
```

## Basic usage

Show help:

```sh
$ alces-job --help
```

Generate a script:

```sh
$ alces-job generate universal --job_name test-job --command "./run.sh"
```

Run interactive mode:

```sh
$ alces-job interactive
```

## Further Help

For more specific guidance, see [UserGuide.md](./UserGuide.md), [DeveloperGuide.md](./DeveloperGuide.md), or [AdminGuide.md](./AdminGuide.md) in the repository root.
