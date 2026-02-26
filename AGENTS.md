# AGENTS.md

Practical guidance for AI agents and other automated contributors in this repository.

## Purpose

This repository is a **chezmoi-based dotfiles setup** with Ansible bootstrap and shell/WM configuration.
The goal is safe, minimal, and idempotent changes.

## Core principles

1. **Keep changes minimal**
   - Make small, focused patches.
   - Do not restructure files or move things unless required.
2. **Fix root causes**
   - When something is broken, correct the source of the issue instead of layering workarounds.
3. **Preserve style**
   - Follow existing patterns in YAML, shell, Lua, and config files.
   - Avoid introducing new tools/frameworks without clear need.
4. **Prioritize idempotency**
   - Ansible tasks and install scripts must remain safe to run repeatedly.

## Repository-specific rules

### Chezmoi

- Edit **source files in this repo**, not generated target files in `$HOME`.
- Respect chezmoi naming conventions (`dot_`, `private_`, `executable_`, `.tmpl`).
- For templates, keep compatibility with current variables and defaults.

### Ansible (`dot_bootstrap/`)

- Keep tasks declarative and idempotent.
- Place new tasks in the most relevant existing role/task files.
- Keep distro-specific logic in the appropriate distro-specific files.

### Shell/scripts (`scripts/`, `private_dot_config/**/scripts/`)

- Match the shell style already used in each file (POSIX/Bash/Fish).
- Do not remove `executable_` prefixes or rename scripts without a clear reason.
- Avoid introducing interactive behavior in scripts used by status bars/hooks.

## Security and secrets

- **Never** commit tokens, passwords, or API keys in plain text.
- Use `.tmpl`, environment variables, or chezmoi encryption for sensitive values.
- Do not log secrets in scripts or playbooks.

## Validation before handoff

Run relevant lightweight checks based on changed files:

```bash
chezmoi diff
chezmoi apply --dry-run
ansible-lint dot_bootstrap/setup.yml
```

For shell changes, run appropriate local lint/tests when available.

## What to include in PRs or handoff notes

- What changed
- Why the change was needed
- How it was validated
- Any assumptions or limitations

## Avoid

- Adding unrequested “nice-to-have” features
- Upgrading unrelated dependencies as part of small fixes
- Touching unrelated files for formatting-only changes