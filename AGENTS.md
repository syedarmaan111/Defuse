# AGENTS.md

## Safety Rules

### Destructive Commands

**Never run destructive or irreversible commands without first asking for and receiving explicit user confirmation.**

This includes, but is not limited to:

- Deleting files or directories (`rm`, `rmdir`, `del`, `Remove-Item`, etc.)
- Force-deleting or recursively deleting data (`rm -rf`, `git clean -fdx`, etc.)
- Overwriting or modifying user data in a way that cannot be easily undone
- Formatting disks or partitions
- Resetting or dropping databases
- Rewriting Git history (`git reset --hard`, `git rebase`, `git push --force`, etc.)
- Commands that uninstall software or remove system packages
- Any operation that could result in permanent data loss

### Confirmation Policy

Before executing any potentially destructive action:

1. Explain what the command will do.
2. Describe the potential consequences, including any data loss.
3. Ask the user for explicit confirmation.
4. Proceed **only** after the user clearly confirms.

Do **not** assume confirmation from context or previous conversations. Obtain confirmation for each destructive operation unless the user has explicitly requested the exact command in the current conversation.
