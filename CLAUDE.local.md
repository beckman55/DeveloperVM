# DevVM Local Notes

## Current Status: FIXED
Provisioning completed manually after fixing VS Code repo conflict.

## Issues Fixed (2025-12-29)
1. **VS Code GPG key conflict** - Two source files with different Signed-By paths
   - Removed `/etc/apt/sources.list.d/vscode.sources`
   - Kept `/etc/apt/sources.list.d/vscode.list`
2. **Missing Claude Code CLI** - Installed via `npm install -g @anthropic-ai/claude-code`
3. **uv symlink broken** - Fixed to point to `/home/developer/.local/bin/uv`
4. **Password hash invalid** - Updated with proper SHA-512 hash

## Repo Fixes Applied
- `ansible/roles/vscode/tasks/main.yml` - Added task to remove conflicting sources
- `iso/nocloud/user-data` - Fixed password hash for "developer"

## Verified Tools
- git 2.43.0
- VS Code 1.107.1
- Python 3.12.3
- uv 0.9.18
- Claude Code 2.0.76
- Docker 29.1.3

## SSH Access
```bash
ssh -i ~/.ssh/devvm_key developer@192.168.1.16
```

## Next Steps
- [ ] Commit and push repo fixes
- [ ] Rebuild ISO to test fixes
