## `ci:watch`

- **Usage**: `ci:watch`

Watch CI running

## `dev:console`

- **Usage**: `dev:console`

Run the application attached to an IEx console

## `dev:fix-translations`

- **Usage**: `dev:fix-translations`

Fix translation file conflicts

## `dev:lint`

- **Usage**: `dev:lint`

Run static checks for code formatting, translations, quality

## `dev:outdated`

- **Usage**: `dev:outdated`

Show outdated dependencies.

## `dev:partitioned-test`

- **Usage**: `dev:partitioned-test <partition_number>`

Run project tests

### Arguments

#### `<partition_number>`

The number of the partition

## `dev:precommit`

- **Usage**: `dev:precommit`

Run checks before a commit

## `dev:readme`

- **Usage**: `dev:readme`

Render README.md with GitHub Flavored Markdown preview

## `dev:setup`

- **Usage**: `dev:setup`

Setup the local development environment

## `dev:update`

- **Usage**: `dev:update`

Update dependencies

## `dev:worktree-setup`

- **Usage**: `dev:worktree-setup`

Bootstrap a git worktree with local config, databases, and a unique port

## `prod:backup`

- **Usage**: `prod:backup`

Backup the production database to the local development env

## `prod:deploy`

- **Usage**: `prod:deploy`

Deploy on production and monitor deployment

## `prod:prune-backups`

- **Usage**: `prod:prune-backups`

Remove locally downloaded production database backups

## `prod:test`

- **Usage**: `prod:test`

Run HTTP tests against production

## `test`

- Depends: dev:partitioned-test 1, dev:partitioned-test 2

- **Usage**: `test`
