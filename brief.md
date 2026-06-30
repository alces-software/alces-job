# Alces JOB - User Stories

This document contains the complete set of user stories for **alces-job**.

- **Version 1** (Original requirements)
- **Version 2** (Proposed new functionality)

---

## Version 1.0 User Stories

### Epic 1: Core Job Script Generation (MVP)

**US-01: Generate a job script from command-line parameters**  
As a new or occasional HPC user,  
I want to generate a complete Slurm job script by passing parameters on the command line,  
so that I don’t have to remember or copy-paste `#SBATCH` syntax.

**Key functionality:**
- Given no existing config, running the tool creates a valid `.sh` file containing correct `#SBATCH` directives.
- The generated script includes a shebang (`#!/bin/bash`), all requested `#SBATCH` lines, and the provided command.
- Output filename defaults to `job-<job-name>.slurm` (or user can override with `-o`).
- The tool exits with code 0 on success and prints a clear success message with the output filename.
- Invalid combinations produce a helpful error message and non-zero exit code.

**US-02: Generate a job using a built-in template**  
As a researcher,  
I want to generate a job script using a built-in template (e.g. mpi, gpu, array),  
so that I get a correctly structured script with best-practice patterns for that job type.

**Key functionality:**
- Usage with advanced options (e.g. MPI) produces a script that uses `srun` (or appropriate launcher) and sets environment variables correctly.
- GPU options use GPU-related setup.
- Array options use a valid array setup.
- Templates include helpful comments explaining key lines.

---

### Epic 2: Interactive & Beginner-Friendly Experience

**US-03: Interactive wizard mode**  
As a user new to Slurm,  
I want an interactive mode that asks me questions step-by-step,  
so that I can generate a correct job script without knowing all the flags.

**Key functionality:**
- Running `alces-job` with no arguments or `--interactive` starts a guided wizard.
- The wizard asks for common fields in a logical order and provides sensible defaults.
- It shows a preview of the generated script and asks for confirmation before writing the file.
- Users can go back and change previous answers.

---

### Epic 3: Workflow Integration

**US-04: Submit job directly after generation**  
As a power user,  
I want to generate and submit a job in one command,  
so that I can iterate quickly without manually running `sbatch`.

**Key functionality:**
- `alces-job my-template --submit` generates the script, shows a preview, and then runs `sbatch`.
- The user is prompted for confirmation before submission (can be skipped with `--yes`).
- On success, it prints the submitted Job ID.
- `--dry-run --submit` shows what would be submitted without actually calling `sbatch`.

**US-05: Validate an existing job script**  
As a user or HPC support staff,  
I want to validate an existing Slurm script,  
so that I can catch common mistakes before submission.

**Key functionality:**
- `alces-job validate job.sh` runs without error on a valid script.
- It detects and reports common issues (missing shebang, duplicate directives, invalid time format, etc.).
- It suggests improvements and can be used in CI pipelines (non-zero exit on errors).

---

### Epic 4: Customization & Reuse

**US-06: Save and reuse profiles**  
As a researcher running many similar jobs,  
I want to save my common settings as a named profile,  
so that I don’t have to re-type the same flags every time.

**Key functionality:**
- `alces-job profile save my-gpu-experiment` creates a reusable profile.
- `alces-job --profile my-gpu-experiment` loads the saved settings (additional flags can still override them).
- Profiles are stored in `~/.config/alces-job/profiles/`.
- `alces-job profile list` shows all available profiles.

**US-07: Create and use custom templates**  
As a power user or lab admin,  
I want to create my own reusable templates,  
so that my team can generate consistent, site-specific job scripts.

**Key functionality:**
- `alces-job template create my-lab-template` creates a new template.
- Custom templates support variables, conditionals, and loops.
- User templates take precedence over built-in ones with the same name.

---

### Epic 5: Usability & Documentation

**US-08: Excellent help and examples**  
As any user,  
I want clear, contextual help and practical examples,  
so that I can quickly understand how to use the tool.

**Key functionality:**
- `alces-job --help` shows well-organized help with examples.
- Subcommand help provides detailed flag descriptions and examples.
- The documentation includes complete examples for serial, MPI, GPU, and job array use cases.
- Shell completion works for commands, flags, and template names.

**US-09: Edit an existing generated script**  
As a user who already has a script,  
I want to quickly modify parameters of an existing script,  
so that I don’t have to regenerate everything from scratch.

**Key functionality:**
- `alces-job edit myjob.sh --time=4:00:00 --mem=16G` updates the relevant `#SBATCH` lines while preserving user-added content.
- A backup of the original file is created (or the user is warned).
- The tool shows a diff of changes before applying them.

---

### Epic 6: Site Administration & Cluster Defaults

**US-10: Provide cluster-wide defaults and guidance as an HPC administrator**  
As an HPC system administrator or research computing support staff,  
I want to deploy a system-wide configuration for alces-job with our cluster’s recommended defaults, valid partitions, typical resource limits, and site-specific modules/advice,  
so that users on our cluster automatically get sensible, up-to-date defaults and are gently guided toward best practices.

**Key functionality:**
- The tool supports a system configuration file at `/etc/alces-job/config.yaml` that merges with (but can be overridden by) the user’s personal config.
- Administrators can define default partitions, accounts, QoS, recommended vs allowed partitions, default modules, output patterns, resource guidance, and cluster-specific GRES types.
- Generated scripts and `--help` can include a note about active site configuration.
- Users can bypass site defaults with `--no-site-config`.

---

## Version 1.1 User Stories

### Epic 7: Environment Modules Integration (v2)

**US-11: Discover available environment modules**  
As an HPC user,  
I want the tool to show me what modules are available on the current system (or from site config),  
so that I can easily find the software and versions I need without running `module avail` separately.

**Key functionality:**
- `alces-job modules list` displays available modules.
- Supports both flat and hierarchical (Lmod-style) module trees.
- Shows short names, full versions, and optional descriptions.
- Respects site configuration for restricted or recommended modules.

**US-12: Search and filter modules**  
As a researcher,  
I want to search for modules by name or category.

**Key functionality:**
- Search supports partial names and wildcards.
- Integrates with the interactive wizard.

**US-13: Select modules to include in the job script**  
As a user generating a job,  
I want to choose modules so that the generated script automatically includes the correct `module load` commands.

**Key functionality:**
- `--module` flag (repeatable) and wizard multi-select support.
- Follows best-practice `module purge` + explicit loads pattern.

**US-14: Handle module versions and recommendations**  
As a user or lab admin,  
I want sensible defaults and warnings when selecting modules.

**Key functionality:**
- Site-defined recommended versions and deprecation warnings.

**US-15: Site-wide module policy and defaults**  
As an HPC administrator,  
I want to define site-recommended modules, blacklists, and defaults.

**Key functionality:**
- System config support for defaults and blacklists.
- `--no-site-config` bypass option.

---

### Epic 8: Full Script Editor Stage (v2)

**US-16: Open generated script in external editor**  
As a user,  
I want the option to open the generated script in `$EDITOR` for final tweaks.

**Key functionality:**
- Prompt after generation/wizard or via `--edit` flag.
- Respects `$EDITOR` / `$VISUAL`.

**US-17: Re-validate and preview after manual editing**  
As a user who edited manually,  
I want re-validation and preview before saving or submitting.

**Key functionality:**
- Automatic validation + diff/preview after editor exit.

**US-18: Seamless handoff to submit / save**  
As a power user,  
I want editing to integrate cleanly with submit/dry-run flows.

**Key functionality:**
- Editor stage occurs before final submit confirmation when `--submit` is used.

**US-19: Remember editor preference**  
As a frequent user,  
I want to configure default editor behaviour.

**Key functionality:**
- User/site config for editor and prompt settings.

**US-29: Save interactive session answers as a reusable profile**  
As a user running the interactive wizard,  
I want the option at the end of the session to save all my answers as a named profile,  
so that I can easily reuse the same configuration in future without having to answer all the questions again.

**Key functionality:**
- At the end of an interactive run, the tool offers to save settings as a profile.
- Prompts for a profile name.
- Saves all collected parameters (resources, modules, template, etc.) for later use with `--profile`.

---

### Epic 9: Job Execution Tracking & Preparation Helpers (v2)

**US-20: Add execution tracking to generated job scripts**  
As a user running jobs through alces-job,  
I want the option to automatically instrument my job script with tracking calls.

**Key functionality:**
- `--track` flag and wizard option.
- Injects `alces_start_job` and `alces_end_job`.

**US-21: Track job start and end events (including output files)**  
As a user running jobs through alces-job.  
I want to know when a tracked job started and finished, along with the locations of its Slurm output and error files.

**Key functionality:**
- `alces_start_job` records timestamps and Slurm `--output` / `--error` filenames.
- Data stored under `~/.alces-job/tracking/<SLURM_JOB_ID>/`.

**US-22: Track internal job stages / phases**  
As a researcher,  
I want to mark logical stages within long-running jobs.

**Key functionality:**
- `alces_stage start` / `alces_stage end` and `alces_note`.

**US-23: Query the status of a tracked job**  
As a user,  
I want `alces-job status <jobid>` to show job state and log file locations.

**Key functionality:**
- Reports state, stages, exit status, and paths to slurm stdout/stderr files.
- doesn't query slurm repeatedly (all tracking is collected by bash functions included in the script that execute when the job starts)

**US-24: View history of tracked jobs**  
As a user,  
I want to list recently tracked jobs and outcomes.

**Key functionality:**
- `alces-job jobs` / `alces-job history` with filtering.

**US-25: Configure tracking behaviour (user and site level)**  
As a user or administrator,  
I want control over tracking storage and retention.

**Key functionality:**
- Configurable tracking directory and retention (user + site).

**US-26: Use tracking functions in scripts submitted outside of alces-job**  
As an advanced user,  
I want to manually source tracking functions in any job script.

**Key functionality:**
- Standalone sourceable functions that record jobid & output filenames when available from slurm (once job starts).

**US-27: Job preparation helper with dedicated working directory**  
As a user generating or running a job,  
I want a preparation helper that sets sensible Slurm output filenames and creates a dedicated working directory named after the job.

**Key functionality:**
- `--prepare` flag or wizard step.
- Sets good default `--output` and `--error` patterns.
- Provides `alces_prepare_job` function that creates and `cd`s into a job-specific working directory.

**US-28: Local scratch execution with automatic result copy-back**  
As a user running single-node jobs,  
I want the option to run from fast local scratch while automatically copying results back to `$HOME` on completion.

**Key functionality:**
- `--local-scratch` flag with configurable scratch path (default `/tmp/$USER`).
- Sourceable functions that run from scratch and copy results back on completion.
- Clearly documented as unsuitable for multi-node jobs.
