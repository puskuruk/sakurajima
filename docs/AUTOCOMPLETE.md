# Shell Autocomplete for Sakurajima Apps

The `sakurajima-apps` command includes intelligent shell autocomplete that dynamically loads available applications from the catalog.

## Features

### Smart Context-Aware Completion

The autocomplete system knows:
- **Available apps** from the catalog (both Docker and Homebrew)
- **Running containers** for stop/remove/logs commands
- **App categories** (database, development, productivity, etc.)
- **App descriptions** shown inline during completion

### What Gets Autocompleted

1. **Commands**: `list`, `install`, `search`, `info`, `running`, `stop`, `remove`, `logs`
2. **Subcommands**: `docker`, `brew`, `all`
3. **App names**: All slugs from `configs/apps-catalog.json`
4. **Running containers**: Only shows containers that are actually running

## Examples

```bash
# Autocomplete install types
$ sakurajima-apps install <TAB>
brew   docker

# Autocomplete Docker apps (with descriptions)
$ sakurajima-apps install docker <TAB>
postgres      -- PostgreSQL database server
redis         -- In-memory data structure store
mongodb       -- NoSQL document database
mysql         -- MySQL relational database
nginx         -- High-performance web server
...

# Autocomplete only running containers
$ sakurajima-apps stop <TAB>
postgres  redis  mongodb  # Only shows what's actually running

# Autocomplete all apps for info/search
$ sakurajima-apps info <TAB>
postgres  redis  mongodb  mysql  nginx  mailhog  minio  ...
obsidian  slack  discord  spotify  vlc  postman  ...
```

## Installation

Autocomplete is automatically installed when you run `./install.sh`. It works in both zsh and bash.

### Manual Installation (if needed)

**For zsh:**
```bash
# Completion is symlinked to ~/.config/zsh/completions/_sakurajima-apps
# and loaded via fpath in .zshrc

# To reload completions:
rm ~/.cache/zsh/zcompdump*
exec zsh
```

**For bash:**
```bash
# Source the completion script in your .bashrc:
source ~/setup/configs/completions/sakurajima-apps.bash
```

## How It Works

### Dynamic Loading

The completion scripts:
1. Read `~/setup/configs/apps-catalog.json` at completion time
2. Parse available apps with `jq`
3. Filter based on context (Docker vs Homebrew, running vs all)
4. Show app descriptions inline for better discovery

### Performance

- Completions are cached by the shell
- JSON parsing happens only when you press TAB
- Typically adds <50ms to completion time

## Troubleshooting

### Autocomplete not working in zsh

```bash
# Check if completions directory exists
ls -la ~/.config/zsh/completions/_sakurajima-apps

# Check if fpath includes the directory
echo $fpath | grep zsh/completions

# Rebuild completion cache
rm ~/.cache/zsh/zcompdump*
autoload -Uz compinit
compinit
```

### Autocomplete not working in bash

```bash
# Check if completion is sourced
type _sakurajima_apps_completion

# Manually source it
source ~/setup/configs/completions/sakurajima-apps.bash

# Add to .bashrc if missing
echo 'source ~/setup/configs/completions/sakurajima-apps.bash' >> ~/.bashrc
```

### Catalog not found error

```bash
# Verify catalog exists
ls -la ~/setup/configs/apps-catalog.json

# Re-run installer if missing
cd ~/setup && ./install.sh
```

### New apps not showing in autocomplete

```bash
# For zsh - rebuild cache
rm ~/.cache/zsh/zcompdump*
exec zsh

# For bash - reload completion
source ~/setup/configs/completions/sakurajima-apps.bash
```

## Adding New Apps

When you add new apps to `configs/apps-catalog.json`, they automatically appear in autocomplete:

1. Edit `~/setup/configs/apps-catalog.json`
2. Add your app to the `docker` or `homebrew` array
3. Restart your shell (or rebuild zsh cache)
4. New app appears in completions!

No need to modify completion scripts - they dynamically read from the catalog.

## Advanced Usage

### Using Completions in Scripts

The completion functions can be used programmatically:

```bash
# Get all Docker app slugs
jq -r '.docker[].slug' ~/setup/configs/apps-catalog.json

# Get all running Sakurajima containers
docker ps --filter 'name=sakurajima-' --format '{{.Names}}' | sed 's/sakurajima-//'

# Get apps by category
jq -r '.docker[] | select(.category == "database") | .slug' ~/setup/configs/apps-catalog.json
```

### Completion Files

- **Zsh**: `~/setup/configs/completions/_sakurajima-apps`
- **Bash**: `~/setup/configs/completions/sakurajima-apps.bash`
- **Symlink**: `~/.config/zsh/completions/_sakurajima-apps` → source file

## Technical Details

### Zsh Completion Format

Uses zsh's `_arguments` framework with:
- `_describe` for showing descriptions
- Dynamic array population from catalog
- State-based context switching

### Bash Completion Format

Uses bash's `COMPREPLY` with:
- `compgen` for word generation
- Case-based context detection
- Dynamic word list from catalog

Both implementations share the same logic but adapt to shell-specific APIs.
