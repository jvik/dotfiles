set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Install lint tooling into .venv
setup:
    uv sync

# Lint the Ansible bootstrap
lint:
    uv run ansible-lint dot_bootstrap/setup.yml

# YAML style check
yamllint:
    uv run yamllint dot_bootstrap

# Preview what chezmoi would change (read-only)
diff:
    chezmoi diff

# Dry-run apply
check:
    chezmoi apply --dry-run

# Apply one source file; avoids a bare apply, which can revert unrelated live edits
apply source:
    chezmoi apply "$(chezmoi target-path {{ source }})"

# Run one bootstrap role from the applied ~/.bootstrap copy (apply it first)
role name:
    ansible-playbook --ask-become-pass -i localhost, -c local --tags {{ name }} "$HOME/.bootstrap/setup.yml"

# Everything AGENTS.md asks for before handoff
validate: lint diff check
