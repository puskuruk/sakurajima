# 📖 Sakurajima — User Guide

This guide documents every flow, tool, and configuration in the Sakurajima environment.

---

## 🌸 The `skr` CLI

The `skr` command is your primary interface for interacting with the system. It abstracts away underlying scripts and complexities.

### Core Commands

| Command | Alias | Description |
| :--- | :--- | :--- |
| `skr verify` | `v` | Runs `verify-system` to check health of tools, configs, and paths. Run this daily. |
| `skr update` | `u` | Updates system tools, Brew packages, repo scripts, and refreshes AeroSpace/Raycast configs. |
| `skr new <client>` | `n` | Provisions a new client workspace (Git identity, SSH keys, directory). |
| `skr infra <cmd>` | `i` | Manages local Docker infrastructure. |

### Infra Commands

| Command | Description |
| :--- | :--- |
| `skr infra up` | Starts MongoDB, Postgres, Redis via Docker Compose. |
| `skr infra down` | Stops the infrastructure. |
| `skr infra backup` | Dumps database states to `~/workspace/backups`. |
| `skr infra status` | Shows running containers and ports. |

---

## 🛠 Tool Usage

### 1. Version Management (`mise`)
We use **mise** (formerly rtx) to manage all language runtimes. It is faster than asdf/fnm and unifies everything.
- **Node.js**: `mise use node@20`
- **Go**: `mise use go@latest`
- **Python**: `mise use python@3.12`
- **Config**: Defined in `~/.config/mise/config.toml` (or local `.mise.toml`).

### 2. Window Management (AeroSpace)
A tiling window manager for macOS.
- **Config**: `~/.config/aerospace.toml` (Generated from `~/setup/configs/aerospace.base.toml` + Clients).
- **Keybindings**:
    - `Alt-1..4`: Switch to static workspaces (Terminal, Internet, Work, Media).
    - `Ctrl-Alt-Cmd-1..9`: Switch to Client workspaces.
    - `Alt-h/j/k/l`: Move focus.
    - `Alt-Shift-h/j/k/l`: Move window.

### 3. Launcher (Raycast)
The command center.
- **Script Commands**: We generate custom scripts for every client.
    - Search "**Sakurajima: Focus <Client>**" to open a terminal in that client's directory.
    - Search "**Sakurajima: Verify System**" to run health checks silently.
- **Extensions**: We install critical extensions like "GitHub", "Docker", "Kill Process".

### 4. Git Identity (Isolated)
You never need to set `user.name` manually.
- **Global**: `~/.gitconfig` sets defaults.
- **Client**: `skr new <client>` creates `~/.config/git/clients/<client>.gitconfig` with specific name/email.
- **Automatic Switching**: The global config uses `[includeIf "gitdir:~/workspace/clients/<client>/"]` to automatically apply the correct identity when you are inside that directory.

---

## 🌊 Workflows

### Creating a New Client
When starting work for a new client/project "Acme Corp":
1. Run: `skr new acme-corp --name "Your Name" --email "you@acme.com"`
   - Creates `~/workspace/clients/acme-corp`
   - Generates SSH key `~/.ssh/keys/gh-acme-corp_ed25519`
   - Adds SSH aliases `github-acme-corp` and `gitlab-acme-corp`
2. Run: `skr update`
   - Regenerates AeroSpace config (assigns a workspace for Acme)
   - Regenerates Raycast scripts (adds "Focus Acme Corp")

### Daily Development
1. **Start**: open Terminal, run `skr verify` to ensure system is clean.
2. **Infra**: `skr infra up` if you need databases.
3. **Code**:
   - `skr focus acme-corp` (or use Raycast)
   - `git clone git@github-acme-corp:acme/repo.git` (Use the alias!)
   - `mise use node@20` (if needed)
   - `code .`

### System Maintenance
- **Updates**: Run `skr update` weekly. It pulls the latest changes from this `~/setup` repo and upgrades Homebrew packages.
- **Backups**: Run `skr infra backup` before scary database operations.

---

## ⚙️ Configuration & Extensibility

### `.zshrc`
- Located at `~/setup/configs/.zshrc` (Symlinked to `~/.zshrc`).
- **Customization**: Create `~/.zshrc.local` for personal aliases/secrets. It is sourced automatically and ignored by git.

### `.gitconfig`
- Located at `~/setup/configs/.gitconfig` (Symlinked to `~/.gitconfig`).
- **Customization**: Create `~/.gitconfig.local` for personal git settings. It is included automatically.

### Docker Data
- Persistence is mapped to `~/workspace/data/{mongo,postgres,redis}`.
- You can inspect these directories directly to see raw data files.
