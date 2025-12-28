```text
You are an expert DevOps engineer. Build a complete, end-to-end unattended Ubuntu Cinnamon “Developer VM” solution that produces a SINGLE custom ISO. The user mounts only one ISO and boots. There are NO Ubuntu install wizards and NO additional ISOs or network seed servers required.

Canonical repo
- Use this GitHub repo as the canonical source: https://github.com/beckman55/DeveloperVM
- Repo name: DeveloperVM

Primary outcome
- A single artifact ISO: DeveloperVM-UbuntuCinnamon-Autoinstall.iso
- User steps: create VM → mount ISO → boot → walk away
- The VM installs Ubuntu unattended, provisions everything, reboots as needed, then auto-logins and presents either:
  - Onboarding wizard (if critical tools present), OR
  - Finish Setup wizard (if critical tools missing)

Important: Keep onboarding and finish-setup wizards (these are post-install account linking wizards). Only eliminate Ubuntu installer wizards and multi-ISO mounting.

Target OS
- Ubuntu 24.04 LTS
- Ubuntu Cinnamon desktop installed and set as default session.

Single ISO requirements (remastered Ubuntu ISO)
1) The ISO must include the NoCloud autoinstall seed embedded inside the ISO filesystem:
   - /nocloud/user-data
   - /nocloud/meta-data
   Also include a backup copy:
   - /autoinstall/nocloud/user-data
   - /autoinstall/nocloud/meta-data

2) The ISO bootloader must automatically boot into autoinstall with kernel args:
   - autoinstall
   - ds=nocloud;s=/cdrom/nocloud/
   and/or an equivalent that reliably reads the embedded seed.

3) Boot fail-safes:
   - Include a secondary GRUB menu entry: “Autoinstall (alternate seed path)” that points to /cdrom/autoinstall/nocloud/
   - Include a “Manual install (recovery)” entry (not default).
   - Add an early check in autoinstall that verifies /cdrom/nocloud/user-data is present; if missing, FAIL LOUDLY (write a clear message to console/log and stop/drop to shell). Do NOT proceed into an interactive installer unexpectedly.

4) Provide a build script in the repo (Linux) to generate the ISO:
   - scripts/build-iso.sh
   It must:
   - Take an Ubuntu 24.04 ISO as input (download or local path).
   - Extract, inject the seed dirs/files, patch boot configs (GRUB).
   - Repack using xorriso/genisoimage.
   - Self-test: mount the resulting ISO and verify:
     - seed files exist in both locations
     - GRUB config contains autoinstall + ds=nocloud parameters
   - Output: build/DeveloperVM-UbuntuCinnamon-Autoinstall.iso

Phase model (state machine)

A) Phase 0: Autoinstall (unattended OS install)
- Create primary user: dev_username (default “developer”) with sudo.
- Set timezone Europe/Berlin.
- Set locale UTF-8 (LANG=en_US.UTF-8, LC_ALL=en_US.UTF-8).
- Install Ubuntu Cinnamon desktop packages.
- Enable OpenSSH server.
- Install minimal bootstrap packages (non-interactive):
  - git, curl, ca-certificates, gnupg, unzip, jq
  - python3, python3-pip
  - (optional) ansible OR install ansible during provisioning bootstrap
- DO NOT enable auto-login yet.
- Install and enable a provisioning systemd unit that will run at boot until provisioning is complete:
  - devvm-provision.service
- Create log + state directories:
  - /var/log/devvm-provision.log
  - /var/lib/devvm/state.json

B) Phase 1: Provisioning (fully unattended, retries + reboots until done)
Implement:
- systemd service: devvm-provision.service (runs at boot)
- runner: /usr/local/sbin/devvm-provision (or similar)

Provisioning behavior (loop):
1) apt update
2) apt full-upgrade -y
3) add required apt repos + signed keys (NO apt-key):
   - VS Code (Microsoft official repo; NOT snap)
   - Docker official repo
   - GitHub CLI official repo
   - Node.js LTS (NodeSource or equivalent)
4) install required packages
5) run configuration via ansible-pull from the canonical repo:
   - ansible-pull pulls this repo and runs the main playbook locally
6) validate critical tools installed (see gating list)
7) if /var/run/reboot-required exists, reboot
8) repeat until:
   - no reboot required
   - validations pass
   - state marked provisioning.done

Guardrails:
- Max retries for transient failures (e.g. 5), exponential backoff
- Detect common apt lock/transient errors and retry
- On persistent failure mark state=needs_attention and STOP the automatic loop (no infinite reboots)
- Ensure all logs go to /var/log/devvm-provision.log and state updates to /var/lib/devvm/state.json

After provisioning SUCCESS:
- Mark /var/lib/devvm/provisioning.done
- Configure system for “wizard visibility” (no sleep/lock/blank)
- Create Desktop assets (Finish Setup, Onboarding, README, optional View Log)
- Enable auto-login for dev user
- Reboot once to land cleanly in GUI auto-login.

After provisioning needs_attention (critical failure):
- Mark /var/lib/devvm/provisioning.needs_attention
- Enable auto-login anyway so user lands on desktop
- Ensure “Finish Setup” auto-launches (instead of onboarding)
- Keep “Skip and Start Onboarding anyway” available.

C) Phase 2: GUI start + wizard selection (auto-login desktop)
At auto-login, a selector must run and choose:
- If critical prerequisites are present => launch Onboarding wizard and focus it.
- If critical prerequisites missing => launch Finish Setup wizard and focus it.
- Always provide desktop shortcuts to run either wizard later.

Critical prerequisites (gate Onboarding auto-launch)
- git
- VS Code (code)
- python3
- uv
- Claude Code CLI
Non-critical failures must NOT block onboarding (fonts, zsh, bat/fzf/tmux, httpie, yq, optional extensions, etc.)

Power/screen requirements (must, so user always sees wizard)
- VM must never sleep, suspend, or hibernate.
- Screen must never blank; screensaver disabled.
- Lock screen disabled.
- DPMS disabled.
Implementation must be robust for Cinnamon:
- Set system defaults (dconf profile/db) so it applies even before user logs in.
- Also set user-level overrides as a safety net.

Wizard visibility
- Ensure the launched wizard is brought to front (wmctrl optional).
- Keep it simple and reliable.

Software list (install + configure via Ansible roles)
1) Core dev + AI
- Ubuntu Cinnamon desktop (already installed during OS install; ensure it’s default)
- git
- VS Code (official repo install; NOT snap)
- Claude Code CLI (install method parameterized; validate install)
- Claude Code VS Code extension/plugin (parameterize ID if uncertain)
- Python3 + pip + venv
- uv
- Node.js LTS

2) Build/system deps
- build-essential
- pkg-config
- cmake
- python3-dev
- libssl-dev
- libffi-dev
- curl, wget, unzip, ca-certificates, gnupg
- jq
- yq
- httpie
- locales + enforce UTF-8 (LANG/LC_ALL)

3) Containers
- Docker Engine
- Docker Compose plugin (docker compose)
- Add dev user to docker group
- Enable/start docker

4) Git workflow
- Git LFS
- GitHub CLI (gh)

5) Productivity
- ripgrep (rg)
- fd-find (fd)
- fzf
- bat
- tmux
- zsh (optional variable enable_zsh, default false)
- direnv

6) Secrets
- Bitwarden CLI (bw)
- No secrets in repo; onboarding guides user login/unlock.

7) VS Code extensions installed idempotently
- ms-python.python
- ms-python.vscode-pylance
- ms-toolsai.jupyter
- Ruff extension (parameterize ID if uncertain)
- GitLens
- Docker
- Dev Containers
- Remote - SSH
- YAML/JSON tooling extension(s)
- Claude Code extension/plugin (parameterize)

8) Onboarding helper UX packages
- zenity
- yad (optional; fallback to zenity)
- xdg-utils
- optionally wmctrl (for focusing) if needed

9) Fonts (optional variable enable_fonts default true)
- Fira Code
- JetBrains Mono

Finish Setup wizard (must)
Purpose:
- For new users, provide a simple button-push recovery if critical prereqs are missing.

Requirements:
- Auto-launch if critical prereqs missing.
- UI shows a checklist:
  - Critical items status (installed/missing)
  - Optional items status (installed/missing)
- Buttons:
  - “Retry Install (Recommended)” -> runs provisioning resume (sudo devvm-provision --resume)
  - “Reboot and Retry”
  - “Skip and Start Onboarding”
  - “View Log” -> opens /var/log/devvm-provision.log
- Safe to run repeatedly. If it achieves readiness, offer “Start Onboarding Now”.

Onboarding wizard (must)
Requirements:
- Auto-launch once when ready (critical prereqs present).
- Skippable steps, stateful, re-runnable via Desktop shortcut “Onboarding”.
- Must support CLI silent mode for power users:
  - devvm-onboarding --cli or --silent
- Store state:
  - ~/.local/share/devvm-onboarding/state.json

Onboarding steps (each skippable):
A) Git identity: prompt user.name and user.email; set global git config.
B) GitHub auth: gh auth login (device flow).
C) SSH: generate ed25519 key if missing; add to agent; offer gh ssh-key add; add github.com to known_hosts.
D) VS Code Settings Sync: launch VS Code and show instructions; confirm sign-in.
E) Bitwarden: bw login/unlock guidance; explain BW_SESSION.
F) OpenAI + Claude API keys:
   - open URLs to key pages
   - guide storing in Bitwarden
   - offer to create per-project direnv template (.envrc) without committing secrets.
G) Docker verification: docker run hello-world; handle “pending until relogin” case.

Desktop assets (must)
- Desktop shortcut: “Finish Setup”
- Desktop shortcut: “Onboarding”
- Desktop file: “README-START-HERE.md” (plain language instructions including CLI silent mode)
- Optional Desktop shortcut: “View Provisioning Log”

Repo deliverables (output format)
You must output a complete repo tree and file contents including:
1) ISO remastering system:
   - iso/nocloud/user-data
   - iso/nocloud/meta-data
   - iso/autoinstall/nocloud/user-data
   - iso/autoinstall/nocloud/meta-data
   - iso/boot-patches/ (GRUB config snippets/patches)
   - scripts/build-iso.sh
   - build/ (output location)

2) Autoinstall seed content (complete YAML)
3) Provisioning system:
   - systemd unit devvm-provision.service
   - runner /usr/local/sbin/devvm-provision
   - state management /var/lib/devvm/state.json
   - log /var/log/devvm-provision.log

4) Ansible repo structure + full contents:
   - ansible.cfg
   - inventory (localhost)
   - group_vars/all.yml with defaults: dev_username, timezone, enable_zsh, enable_fonts, repo_url, branch, retry limits, etc.
   - site.yml
   - roles/* with idempotent tasks and handlers

5) GUI wizard selector:
   - autostart entry or systemd --user service that runs after GUI login and decides which wizard to show
6) Onboarding scripts:
   - devvm-onboarding (GUI + CLI)
7) Finish Setup scripts:
   - devvm-finish-setup (GUI)
8) Desktop .desktop files for Finish Setup, Onboarding, View Log
9) Desktop README content (README-START-HERE.md)
10) Root README.md with:
   - How to build the ISO
   - How to use it
   - What happens on first boot (provisioning loop)
   - What happens on first login
   - Troubleshooting and log locations

Implementation notes / constraints
- Everything idempotent.
- Use signed keys, no apt-key.
- Avoid Snap for VS Code.
- Do not store secrets in repo.
- Avoid printing secrets to logs.
- Use become correctly.
- For uncertain items (Claude Code install method, Claude VS Code extension ID, Ruff extension ID), parameterize and document in README and Desktop README, but still deliver a cohesive working solution.

Proceed now:
- Output full repo tree
- Then each file content
- Ensure the solution is cohesive and runnable.
```
