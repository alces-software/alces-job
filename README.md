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
$ wget https://github.com/alces-software/alces-job/releases/PUT_GEM_HERE
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