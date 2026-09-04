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
- `chezmoi apply`/`chezmoi diff` take the **target path** (under `$HOME`), never the
  source path in this repo — `chezmoi apply private_dot_config/fish/functions/foo.fish`
  fails with "not managed". Convert with `chezmoi target-path <source-path>`, or just
  apply the equivalent `$HOME` path directly, e.g.
  `chezmoi apply ~/.config/fish/functions/foo.fish`.
- Prefer applying a **scoped target path** over a bare `chezmoi apply` — a bare apply
  re-applies every managed file, which can revert unrelated in-progress edits elsewhere
  in `$HOME` (e.g. `.claude/settings.json`).

### Ansible (`dot_bootstrap/`)

- Keep tasks declarative and idempotent.
- Place new tasks in the most relevant existing role/task files.
- Keep distro-specific logic in the appropriate distro-specific files.

### Shell/scripts (`scripts/`, `private_dot_config/**/scripts/`)

- Match the shell style already used in each file (POSIX/Bash/Fish).
- Do not remove `executable_` prefixes or rename scripts without a clear reason.
- Avoid introducing interactive behavior in scripts used by status bars/hooks.
- **Long-running sway helpers belong in a systemd user unit**, not in
  `exec_always "pkill -f <name>; <name>"`. sway runs `exec_always` through
  `sh -c "<the whole string>"`, so that shell's own argv matches the pkill
  pattern and it kills itself before reaching the `;` — a watcher started that
  way never runs. See `private_dot_config/systemd/user/sway-output-watch.service`.
- When subscribing with `swaymsg -t subscribe`, pass `--monitor`. Without it
  swaymsg exits after the first event and the script silently dies.

### Terminal/shell environment

- The user's interactive shell is **fish**. All commands suggested or run in the terminal must be fish-compliant.
- Do not use Bash-only syntax (e.g. `[[ ]]`, `export VAR=val`, `$(...)` in assignments) when writing commands to run interactively.
- Use fish syntax: `set VAR val`, `string` builtins, `(command)` substitution, etc.

### Device-specific config

The following files embed hardware identifiers and must reflect the current machine's hardware:

- `private_dot_config/kanshi/config` — monitor identifiers in profile names and `output` directives. Most desks are covered by per-family glob profiles (`"Samsung Electric Company LS49C95xU *"`) and a final `fallback-docked` catch-all, so a new monitor usually needs no profile at all. kanshi takes the **first** matching profile, so order matters: specific desks → family globs → `fallback-docked` last.
- `private_dot_config/sway/config` — touchpad input IDs and the hardcoded wallpaper path
- `private_dot_config/solaar/config.yaml` — Logitech peripheral serial numbers (MX Master, MX Keys, etc.)
- `dot_var/app/hu.irl.cameractrls/` — camera device identifiers encoded in filenames

When any hardware changes (displays, input devices, peripherals, cameras), update the relevant files above and keep this list and the matching section in [readme.md](readme.md) accurate.

### Documentation (`readme.md`, `AGENTS.md`)

- Keep [readme.md](readme.md) up-to-date when making significant changes to the repository structure or configuration.
- Document new roles, major features, or configuration sections in the readme.
- Maintain accuracy of any setup or usage instructions.
- Update [AGENTS.md](AGENTS.md) when core functionality changes: new repository conventions, renamed/reorganised directories, new tooling or shells, or changes to validation steps.

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