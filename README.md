# DevVM - Developer Virtual Machine

An automated, unattended Ubuntu Cinnamon developer environment that provisions itself from a single bootable ISO.

## Overview

DevVM creates a single custom ISO that:
1. Boots and installs Ubuntu 24.04 LTS with Cinnamon desktop unattended
2. Automatically provisions all development tools via Ansible
3. Presents an onboarding wizard on first login

**User steps:** Create VM → Mount ISO → Boot → Walk away → Return to a configured dev environment

## Quick Start

### Building the ISO

```bash
# Clone the repository
git clone https://github.com/beckman55/DeveloperVM.git
cd DeveloperVM

# Build the ISO (downloads Ubuntu ISO if needed)
./scripts/build-iso.sh --download

# Or use an existing Ubuntu ISO
./scripts/build-iso.sh --source-iso ~/Downloads/ubuntu-24.04.1-desktop-amd64.iso
```

The output ISO will be at: `build/DeveloperVM-UbuntuCinnamon-Autoinstall.iso`

### Using the ISO

1. Create a new VM in VirtualBox, VMware, or your preferred hypervisor
   - Recommended: 4+ CPU cores, 8GB+ RAM, 50GB+ disk
   - Make sure the BIOS is set to UEFI
2. Mount `DeveloperVM-UbuntuCinnamon-Autoinstall.iso` as the boot media
3. Boot the VM
4. Wait for installation and provisioning to complete (30-60 minutes)
5. The system will auto-login and present the onboarding wizard

## What Happens on First Boot

### Phase 0: Autoinstall (OS Installation)
- Ubuntu 24.04 LTS installs automatically
- Creates user `developer` with sudo privileges
- Installs Cinnamon desktop environment
- Enables SSH server
- Sets timezone to Europe/Berlin, locale to en_US.UTF-8

### Phase 1: Provisioning (Fully Automated)
The `devvm-provision` service runs at boot and:
1. Updates system packages
2. Adds required repositories (VS Code, Docker, GitHub CLI, Node.js)
3. Installs all development tools via Ansible
4. Validates critical tools are installed
5. Reboots if required, repeats until complete
6. Enables auto-login for first desktop experience

**Guardrails:**
- Maximum 5 retries with exponential backoff
- Logs everything to `/var/log/devvm-provision.log`
- On persistent failure, marks state as `needs_attention` and stops

### Phase 2: Desktop Login
On first GUI login:
- If all critical tools present → **Onboarding Wizard** launches
- If critical tools missing → **Finish Setup Wizard** launches

## Installed Software

### Critical Tools (Gate Onboarding)
- git
- VS Code (official repo, not Snap)
- Python 3 with pip/venv
- uv (Python package manager)
- Claude Code CLI

### Development Stack
- **Languages:** Python 3, Node.js LTS
- **Editors:** VS Code with extensions
- **Containers:** Docker Engine, Docker Compose
- **Version Control:** Git, Git LFS, GitHub CLI

### Productivity
- ripgrep, fd-find, fzf, bat
- tmux, direnv
- jq, yq, httpie

### Security
- Bitwarden CLI
- OpenSSH Server

### VS Code Extensions
- Python, Pylance, Jupyter
- Ruff (linting)
- GitLens, Docker, Dev Containers
- Remote SSH, YAML tools
- Claude Code extension

### Optional
- Zsh with oh-my-zsh (set `enable_zsh: true`)
- Fira Code, JetBrains Mono fonts (set `enable_fonts: true`)

## Wizards

### Onboarding Wizard
Guides users through:
1. Git identity configuration
2. GitHub authentication (device flow)
3. SSH key generation and GitHub upload
4. VS Code Settings Sync
5. Bitwarden CLI login
6. API key setup (Anthropic, OpenAI)
7. Docker verification

**CLI Mode:**
```bash
devvm-onboarding --cli     # Interactive CLI
devvm-onboarding --silent  # Non-interactive
```

### Finish Setup Wizard
Helps resolve installation issues:
- Shows checklist of installed/missing tools
- Retry installation with one click
- Reboot and retry option
- View provisioning log
- Skip to onboarding

## Repository Structure

```
DeveloperVM/
├── iso/                          # ISO build artifacts
│   ├── nocloud/                  # Primary autoinstall seed
│   │   ├── user-data
│   │   └── meta-data
│   ├── autoinstall/nocloud/      # Backup seed location
│   └── boot-patches/             # GRUB configuration patches
├── scripts/
│   ├── build-iso.sh              # ISO builder script
│   ├── devvm-provision           # Provisioning runner
│   ├── devvm-onboarding          # Onboarding wizard
│   ├── devvm-finish-setup        # Finish setup wizard
│   └── devvm-wizard-selector     # Wizard launcher
├── systemd/
│   └── devvm-provision.service   # Provisioning systemd unit
├── ansible/
│   ├── ansible.cfg
│   ├── inventory
│   ├── group_vars/all.yml        # Configuration variables
│   ├── site.yml                  # Main playbook
│   └── roles/                    # Ansible roles
│       ├── locale/
│       ├── base-packages/
│       ├── docker/
│       ├── nodejs/
│       ├── python/
│       ├── vscode/
│       ├── git-tools/
│       ├── productivity/
│       ├── bitwarden/
│       ├── claude-code/
│       ├── fonts/
│       ├── zsh/
│       ├── desktop-assets/
│       └── power-settings/
├── desktop/                      # Desktop files
└── build/                        # ISO output directory
```

## Configuration

Edit `ansible/group_vars/all.yml` to customize:

```yaml
# User
dev_username: developer

# System
timezone: Europe/Berlin
locale: en_US.UTF-8

# Features
enable_zsh: false      # Install zsh + oh-my-zsh
enable_fonts: true     # Install coding fonts

# Claude Code (parameterized)
claude_code_install_method: npm
claude_code_npm_package: "@anthropic-ai/claude-code"

# VS Code extensions
vscode_extensions:
  - ms-python.python
  - ms-python.vscode-pylance
  # ... add more as needed
```

## Troubleshooting

### View Logs
```bash
# Provisioning log
cat /var/log/devvm-provision.log

# Ansible log
cat /var/log/devvm-ansible.log

# System journal
journalctl -u devvm-provision
```

### Check State
```bash
cat /var/lib/devvm/state.json | jq
```

### Resume Provisioning
```bash
sudo devvm-provision --resume
```

### Docker Group Membership
If Docker commands fail after provisioning:
```bash
# Log out and back in, or:
newgrp docker
```

### ISO Boot Issues
The ISO includes fallback options:
- "Install DevVM Ubuntu (Autoinstall)" - Primary
- "Install DevVM Ubuntu (Alternate Seed Path)" - Backup seed location
- "Manual Install (Recovery)" - Standard Ubuntu installer

## Parameterized/Uncertain Items

Some items have parameterized IDs that may need updating:

| Item | Variable | Current Value |
|------|----------|---------------|
| Claude Code CLI | `claude_code_npm_package` | `@anthropic-ai/claude-code` |
| Claude VS Code Extension | In `vscode_extensions` | `anthropic.claude-code` |
| Ruff Extension | In `vscode_extensions` | `charliermarsh.ruff` |

If installation fails for these items, verify the current package/extension IDs and update `ansible/group_vars/all.yml`.

## Contributing

1. Fork the repository
2. Make changes
3. Test by building and booting the ISO
4. Submit a pull request

## License

MIT License - See LICENSE file for details.

---

**Repository:** https://github.com/beckman55/DeveloperVM
