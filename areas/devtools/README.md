# Developer Tools

This area provides various developer tools and utilities for JB-VPS development and maintenance.

## Available Tools

### Snapshot & Push Repository

Quickly stage, commit, and push all changes to the repository with a single command.

- Stages all modified files
- Creates a commit with a custom or auto-generated message
- Pushes changes to the remote repository

#### Usage

- From menu: Developer Tools → "Snapshot & push repo"
- From CLI: `jb repo:snapshot [--preview] [--message "your commit message"]`

#### Options

- `--preview`: Show what would be committed without making changes
- `--message "text"`: Specify a commit message (alternatively, set the `GIT_COMMIT_MSG` environment variable)

If no message is provided, you'll be prompted to enter one or use the default timestamp-based message.

#### Features

- Idempotent operation (won't create empty commits)
- Clear preview mode to review changes before committing
- Displays repository status, current branch, and commit information
- Verifies Git user identity is properly configured

## Other Development Tools

More developer tools will be added in future releases, including:

- Syntax checking
- Unit test runners
- Code linting tools
- Static analysis
