# Welcome to DevVM - Your Developer Environment

Congratulations! Your Developer VM has been set up and is ready for configuration.

## Quick Start

### If you see the Onboarding Wizard
Great! All critical tools are installed. Follow the wizard to:
1. Configure your Git identity
2. Authenticate with GitHub
3. Set up SSH keys
4. Configure VS Code settings sync
5. Set up Bitwarden for secrets management
6. Configure API keys for AI tools

### If you see the Finish Setup Wizard
Some critical tools may need attention. The wizard will help you:
1. See what's installed and what's missing
2. Retry the installation
3. View logs for troubleshooting
4. Skip to onboarding if you prefer

## Desktop Shortcuts

- **Onboarding** - Run the onboarding wizard anytime
- **Finish Setup** - Check/fix installation status
- **View Provisioning Log** - See detailed installation logs

## CLI Usage

For power users who prefer the command line:

```bash
# Run onboarding in CLI mode
devvm-onboarding --cli

# Run onboarding silently (non-interactive)
devvm-onboarding --silent

# Resume provisioning manually
sudo devvm-provision --resume

# Check provisioning status
cat /var/lib/devvm/state.json | jq
```

## What's Installed

### Development Tools
- **VS Code** - Code editor with extensions
- **Git** - Version control with LFS support
- **GitHub CLI** - Command-line GitHub interface
- **Docker** - Container runtime with Compose

### Programming Languages
- **Python 3** - With pip and venv
- **uv** - Fast Python package manager
- **Node.js LTS** - JavaScript runtime

### AI Development
- **Claude Code CLI** - AI coding assistant
  - Note: Requires ANTHROPIC_API_KEY to function
  - Configure during onboarding or set manually

### Productivity Tools
- **ripgrep (rg)** - Fast text search
- **fd** - Fast file finder
- **fzf** - Fuzzy finder
- **bat** - Better cat with syntax highlighting
- **tmux** - Terminal multiplexer
- **direnv** - Environment variable manager
- **jq/yq** - JSON/YAML processors

### Security
- **Bitwarden CLI** - Password manager CLI
- **SSH** - OpenSSH server enabled

## Configuration Files

- Provisioning state: `/var/lib/devvm/state.json`
- Provisioning log: `/var/log/devvm-provision.log`
- Onboarding state: `~/.local/share/devvm-onboarding/state.json`

## Troubleshooting

### Installation Issues
1. Check the provisioning log: `View Provisioning Log` shortcut
2. Run `sudo devvm-provision --resume` to retry
3. Check network connectivity

### Docker Not Working
You may need to log out and back in for group membership to take effect:
```bash
# Check if you're in the docker group
groups

# If docker is not listed, log out and back in
# Or run: newgrp docker
```

### Claude Code Not Working
Ensure you have set your API key:
```bash
# Set temporarily
export ANTHROPIC_API_KEY="your-key-here"

# Or use direnv with a .envrc file
echo 'export ANTHROPIC_API_KEY="your-key-here"' > ~/.envrc
direnv allow
```

## Parameterized/Uncertain Items

Some installation details may need adjustment:

| Item | Current Setting | Notes |
|------|----------------|-------|
| Claude Code CLI | npm: @anthropic-ai/claude-code | Update if package name changes |
| Claude VS Code Extension | anthropic.claude-code | Verify extension ID in marketplace |
| Ruff Extension | charliermarsh.ruff | Verify extension ID in marketplace |

If any of these fail to install, check the marketplace for current IDs and update
`/tmp/devvm-ansible/ansible/group_vars/all.yml` before running provisioning again.

## Getting Help

- Repository: https://github.com/beckman55/DeveloperVM
- Provisioning log: `/var/log/devvm-provision.log`
- System journal: `journalctl -u devvm-provision`

---
*DevVM - Automated Developer Environment Setup*
