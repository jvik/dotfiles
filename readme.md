# Dotfiles

Personal, reproducible Linux (and macOS-friendly) workstation setup powered by:

* [chezmoi](https://www.chezmoi.io/) for dotfile management & templating
* [Ansible](https://www.ansible.com/) for bootstrapping packages & system state
* Modern tooling: zsh, Homebrew (Linuxbrew), LazyVim, WezTerm, sway/i3 environment, Wayland components

> Goal: One command to bring a fresh machine to a comfortable, fully-configured environment.

---

## Quick Start

Pick your tiling window manager (currently optimized for sway; i3 fallback logic included):

```bash
export TILING_MANAGER=sway        # or i3
export GITHUB_USERNAME=jvik       # replace with your GitHub username (fork first!)
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply "$GITHUB_USERNAME"
```

That chezmoi command will:
1. Clone the dotfiles repo.
2. Apply tracked files into your home directory.
3. Run any `run_once_*` and `run_onchange_*` scripts (installs Ansible if missing).

Then run the bootstrap playbook (if not already done):

```bash
~/.local/share/chezmoi/run_install_02.sh   # executes ansible-playbook with privilege escalation prompt
```

You can re-run safely; tasks are idempotent.

---

## Requirements

Minimal before first run:

* curl & git (for initial chezmoi installer)
* A POSIX shell (bash/zsh)
* sudo access (for package installs)

Automatically handled / installed:

* Ansible (via `run_once_01_install_ansible.sh` for Fedora. Other distros are not tested, but Ubuntu/Debian will likely work.)
* Homebrew (Linuxbrew) if not present (installed by Ansible playbook)
* oh-my-zsh (if absent)

---

## Ansible Bootstrapping

Playbook: `dot_bootstrap/setup.yml`

Automatically executed by chezmoi.

Key tasks:
* Install base packages (fd-find, tree, flatpak, ansible-lint, htop, blueman, wezterm etc.)
* Conditional sway stack install when `window_manager == "sway"`
* Flatpak application installation
* Set login shell to zsh for user
* Install Homebrew (if missing) and package set.
* Install fonts via Homebrew casks

Template vars file created at `~/.bootstrap/vars.yml` from `vars.yml.tmpl`. Edit that file and rerun `run_onchange_install_02.sh` to apply changes.

Dry run / lint (optional):

```bash
ansible-lint dot_bootstrap/setup.yml
ansible-playbook -i localhost, -c local --check ~/.bootstrap/setup.yml
```

---

## Neovim (LazyVim)

Neovim loads via `private_dot_config/nvim/init.lua` which bootstraps LazyVim with plugins in `lua/plugins/` (examples: colorscheme, hop, tmux navigator). Customize by adding plugin specification files under `lua/plugins/` or editing `lua/config/` (options, keymaps, autocmds).

Update plugins:

```bash
nvim +Lazy sync +qall
```

Style formatting controlled via `stylua.toml`.

---

## Wayland / WM Stack

When `TILING_MANAGER=sway`:
* sway main config in `private_dot_config/sway/config`
* color schemes in `private_dot_config/sway/colors/`
* waybar config & style under `private_dot_config/waybar/`
* notifications: `private_dot_config/swaync/`
* launcher: `private_dot_config/wofi/`

For i3, placeholder logic exists; add i3 package tasks & configs similarly beneath `private_dot_config/i3/`.

Lock script: `private_dot_config/sway/lockman.sh` (adaptable to i3 if needed).

---

## Updating & Maintaining

Common chezmoi commands:

```bash
chezmoi diff              # See pending changes
chezmoi edit <file>       # Edit a managed file in $EDITOR
chezmoi apply             # Apply all changes
chezmoi update            # Pull latest from origin (dotfiles repo)
```

Regenerate templates after editing vars:

```bash
chezmoi apply ~/.bootstrap/vars.yml.tmpl
```

Re-run provisioning:

```bash
~/.local/share/chezmoi/run_install_02.sh
```

---

## Customization Tips

* Add new packages: edit `dot_bootstrap/setup.yml` (group by function; keep idempotent).
* Add secrets: use chezmoi encryption (`age` or `gpg`) and keep them out of public repo. Prefer `.tmpl` with environment lookups instead of committing raw secrets.
* Extend zsh: put functions in `private_dot_config/zsh/functions.zsh` (already provided) or use `antigen.zsh` for extra bundles.
* Override local-only settings: create `private_dot_config/zsh/local.zsh` (see `local.zsh.example`). chezmoi can ignore or manage with encryption.

### Wallpaper

https://drive.proton.me/urls/K1NFJPP43M#p1daHRRboBCZ

Add to ~/.wallpaper


---

## Scripts

Utility scripts live in `scripts/`. Example: `present-select.sh` (likely a helper for presentation profile selection). Make scripts executable:

```bash
chmod +x scripts/*.sh
```

Add to PATH (zsh):

```bash
export PATH="$HOME/scripts:$PATH"
```

---

## License

This repository (dotfiles and original configuration content) is released under the Apache License 2.0. See `private_dot_config/nvim/LICENSE` for the license text. Third-party tools, plugins, and fonts retain their respective licenses.
