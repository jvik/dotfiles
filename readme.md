# Dotfiles

Personal, reproducible Linux (and macOS-friendly) workstation setup powered by:

* [chezmoi](https://www.chezmoi.io/) for dotfile management & templating
* [Ansible](https://www.ansible.com/) for bootstrapping packages & system state
* Modern tooling: zsh, Homebrew (Linuxbrew), LazyVim, WezTerm, sway/Wayland environment

> Goal: One command to bring a fresh machine to a comfortable, fully-configured environment.

---

## Quick Start

```bash
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

The install script defaults to `ANSIBLE_VERBOSITY=1` for extra task output. For deeper troubleshooting, increase it temporarily:

```bash
ANSIBLE_VERBOSITY=2 ~/.local/share/chezmoi/run_install_02.sh
ANSIBLE_VERBOSITY=3 ~/.local/share/chezmoi/run_install_02.sh
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
* Sway stack install (sway, waybar, fuzzel, SwayNotificationCenter, wdisplays, lxpolkit)
* Flatpak application installation
* Set login shell to zsh for user
* Install Homebrew (if missing) and package set.
* Install fonts via Homebrew casks

Template vars file created at `~/.bootstrap/vars.yml` from `vars.yml.tmpl`.

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

Sway is the window manager. Configuration lives under:
* `private_dot_config/sway/config` — main sway config and color schemes
* `private_dot_config/waybar/` — status bar config & style
* `private_dot_config/swaync/` — notifications
* `private_dot_config/fuzzel/` — launcher

Lock script: `private_dot_config/sway/lockman.sh`.

Keyboard shortcut overlay: `$mod+?` opens a searchable fuzzel palette of every keybinding, built by `scripts/sway-shortcuts.sh` parsing the live sway config (including `include`d files) at invocation time — there is no cheatsheet file to keep in sync. Bindings are grouped by the `##` section headers already in the config, mode bindings are shown prefixed with the key that enters the mode (`$mod+p → r`), and selecting an entry runs it via `swaymsg`. Descriptions are derived from the sway command; to override one, put a `#: some description` comment on the line directly above the `bindsym` (sway ignores it). Run `scripts/sway-shortcuts.sh --dump` to inspect the parsed rows without opening the overlay.

Network management: clicking the wlan tile in waybar (or the network icon in the swaync quick actions) opens [`networkmanager_dmenu`](https://github.com/firecat53/networkmanager-dmenu) via fuzzel — lists APs with signal strength, connects/forgets networks, and includes a "Rescan WiFi Networks" action (unlike `nmtui`). Installed by the `extras` Ansible role; configured at `private_dot_config/networkmanager-dmenu/config.ini`.

Screenshots: `$mod+p` / `Print` freezes the screen with [`wayfreeze`](https://github.com/Jappie3/wayfreeze) and opens a sway mode to pick region/full/window capture (`r`/`f`/`w`) — see `scripts/satty-screenshot.sh`. The frozen overlay ensures the capture matches what was on screen when the shortcut was pressed, not whatever's on screen once you finish selecting. Since satty is a plain xdg-toplevel and sway renders it behind a fullscreen window, the script drops fullscreen on the focused workspace once the capture is on disk and restores it when satty exits. Installed by the `extras` Ansible role.

---

## Device-Specific Configuration

Some files contain hardware identifiers or device settings tied to specific machines. Review and update these when setting up on new hardware:

- **`private_dot_config/kanshi/config`** — Display profiles. Per-family glob profiles (`"Samsung Electric Company LS49C95xU *"`) cover most desks and a final `fallback-docked` catch-all handles anything unrecognised, so a new monitor usually needs no profile at all. Add one only when a desk needs different geometry, with `scripts/kanshi-append-config.sh` (which inserts before the catch-all) or by editing directly. kanshi takes the first matching profile, so `fallback-docked` must stay last.
- **`private_dot_config/sway/config`** — Touchpad input device IDs (e.g. `input "1739:52839:SYNA8018:00_06CB:CE67_Touchpad"`) and the wallpaper path (`/home/jorgen/.wallpaper`).
- **`private_dot_config/solaar/config.yaml`** — Logitech peripheral settings containing per-device serial numbers (MX Master 3S, MX Keys, etc.).
- **`dot_var/app/hu.irl.cameractrls/`** — Camera control settings with PCI/USB device identifiers encoded in the filenames.

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
