# Dotfiles

Personal, reproducible Linux (and macOS-friendly) workstation setup powered by:

* [chezmoi](https://www.chezmoi.io/) for dotfile management & templating
* [Ansible](https://www.ansible.com/) for bootstrapping packages & system state
* Modern tooling: Homebrew (Linuxbrew), LazyVim, WezTerm, sway/Wayland environment

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
* A POSIX shell (bash)
* sudo access (for package installs)

Automatically handled / installed:

* Ansible (via `run_once_01_install_ansible.sh` for Fedora. Other distros are not tested, but Ubuntu/Debian will likely work.)
* Homebrew (Linuxbrew) if not present (installed by Ansible playbook)

---

## Ansible Bootstrapping

Playbook: `dot_bootstrap/setup.yml`

Automatically executed by chezmoi.

Key tasks:
* Install base packages (fd-find, tree, flatpak, ansible-lint, htop, blueman, wezterm etc.)
* Sway stack install (sway, waybar, fuzzel, SwayNotificationCenter, wdisplays, lxpolkit)
* Flatpak application installation
* Set login shell to fish for user
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
- **`private_dot_config/sway/config`** — Touchpad input device IDs (e.g. `input "1739:52839:SYNA8018:00_06CB:CE67_Touchpad"`). The wallpaper is no longer device-specific: `set-wallpaper.sh` picks per output by aspect ratio at runtime, so new displays need no config change.
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

Update packages (dnf/apt, Homebrew formulae, Flatpak) via
[topgrade](https://github.com/topgrade-rs/topgrade), installed by the Homebrew role
and configured at `private_dot_config/topgrade.toml` (→ `~/.config/topgrade.toml`):

```bash
sysup          # topgrade
sysup-check    # topgrade --dry-run
```

The Signal Desktop AppImage (GPG-verified download, outside topgrade's scope) has
its own playbook:

```bash
sysup-signal   # ansible-playbook ~/.bootstrap/update-signal.yml
```

---

## Customization Tips

* Add new packages: edit `dot_bootstrap/setup.yml` (group by function; keep idempotent).
* Add secrets: use chezmoi encryption (`age` or `gpg`) and keep them out of public repo. Prefer `.tmpl` with environment lookups instead of committing raw secrets.
* Extend fish: add functions under `private_dot_config/fish/functions/`.
* Override local-only settings: create `private_dot_config/fish/local.fish` (see `local.fish.example`). chezmoi can ignore or manage with encryption.

### Wallpaper

Wallpapers are chosen **per output, by aspect ratio**, and follow darkman. A single image cannot
serve this hardware — the office desks are 32:9 (5120x1440, 3840x1080), home is 21:9 (3840x1600)
and the laptop panel is 16:10 (1920x1200) — because sway's `fill` covers the output and crops the
rest, so a 16:9 source loses the vertical middle 50% on an ultrawide.

Images live outside the repo at:

```
~/Pictures/wallpapers/<dark|light>/<standard|wide|ultrawide>/
```

Buckets are by aspect ratio: `>= 3.0` → `ultrawide`, `>= 2.0` → `wide`, else `standard`.

Populate them with:

```bash
~/scripts/generate-wallpapers.sh      # FORCE=1 to regenerate
```

Everything is **generated, not downloaded** — 27 files, ~3.6MB, a couple of seconds. Each preset is
rendered once per bucket at that bucket's native resolution, so every output gets an exact fit and
nothing is ever cropped. There is no source repo to curate and no photography: stock wallpapers
either fought the theme or turned out to be novelty images wearing a gruvbox palette.

The presets deliberately **complement gruvbox rather than reproduce it.** Filling the desktop with
the same warm ochres as the chrome makes the whole screen one muddy yellow-brown; these sit on the
cool side so the warm `#ebdbb2` text and `#fabd2f` accents read as accents against them:

| Mode | Presets |
|---|---|
| dark | `abyss` teal→indigo, `nocturne` plum→navy, `tide` teal→blue, `ultra` indigo→teal, `moss` green→teal |
| light | `haze`, `mist`, `glacier`, `bloom` — pale blue/lilac, cool against the `#fbf1c7` chrome |

Each is a four-corner bilinear mesh rather than a two-stop ramp, so the colour travels across the
frame instead of banding in one direction — which is what stops a 5120px-wide background reading as
a flat field. Faint Gaussian noise dithers it: these ramps span only ~20 8-bit levels, so over 1440
rows they band visibly without it. Output is JPEG q92 — at 5120x1440 that is ~200KB and 0.3s, versus
6.2MB and 12s as 8-bit PNG (32MB at PNG's default 16-bit depth), and noise does not compress
losslessly.

Add your own images to any bucket and they join the rotation; the picker does not care where a file
came from, only which directory it is in. It never falls back to a *different* bucket — an empty
bucket yields a solid gruvbox colour instead, because borrowing a 16:10 image for a 32:9 output
would crop away more than half of it, which is the failure this whole arrangement exists to avoid.

`private_dot_config/sway/scripts/set-wallpaper.sh` does the picking and applying. It runs at sway
startup, from `on-output-change.sh` on every hotplug, and from the darkman `40-wallpaper` hook on
theme changes. `--print` emits `<output>\t<path>` without applying, which is how `lockman.sh` gives
swaylock one `-i <output>:<path>` per head. Selection is deterministic (hash of the output name), so
a hotplug or DPMS wake never reshuffles the desktop, and two heads never land on the same image.


---

## Shell

The interactive shell is fish (`private_dot_config/fish/`, documented in its own
[README](private_dot_config/fish/README.md)).

Shortcut picker: `ab` fuzzy-finds every abbreviation, alias and custom function and puts the
chosen **name** on the command line, so `<space>` expands it and you learn the shortcut rather
than just running the command — the terminal counterpart to `$mod+?` in sway. The list is built
from `abbr --show`, `alias` and `functions` at invocation time, so there is no cheatsheet file to
keep in sync; of the ~229 entries only ~65 come from `abbr.fish`, the rest from the
`lewisacidic/fish-git-abbr` plugin. fzf matches against the expansion as well as the name, so
`ab commit` finds `gcm`. Run `ab --dump` to inspect the parsed rows without opening the picker.

---

## Scripts

Utility scripts live in `scripts/`. Example: `present-select.sh` (likely a helper for presentation profile selection). Make scripts executable:

```bash
chmod +x scripts/*.sh
```

Add to PATH (fish):

```fish
fish_add_path $HOME/scripts
```

---

## License

This repository (dotfiles and original configuration content) is released under the Apache License 2.0. See `private_dot_config/nvim/LICENSE` for the license text. Third-party tools, plugins, and fonts retain their respective licenses.
