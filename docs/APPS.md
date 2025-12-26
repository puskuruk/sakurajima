# Sakurajima Apps - Omakub-Style Application Management

Sakurajima includes an Omakub-inspired application installation system that makes it easy to install and manage both Docker containers and Homebrew applications from a central catalog.

## Overview

The app management system consists of:
- **App Catalog** (`configs/apps-catalog.json`) - Central registry of available applications
- **CLI Tool** (`sakurajima-apps`) - Command-line interface for app management
- **Raycast Integration** - Quick access to browse and install apps via Raycast

## Installation Methods

### Via Raycast (Recommended)

1. **Browse Available Apps**
   - Open Raycast → Type "Browse Docker Apps" or "Browse Homebrew Apps"
   - View all available applications organized by category

2. **Install Apps**
   - Open Raycast → Type "Install Docker App" or "Install Homebrew App"
   - Enter the app slug (e.g., `postgres`, `redis`, `obsidian`)
   - The app will be installed automatically

### Via Command Line

```bash
# List available apps
sakurajima-apps list docker          # Docker containers
sakurajima-apps list brew             # Homebrew apps
sakurajima-apps list all              # All apps

# Search for apps
sakurajima-apps search database
sakurajima-apps search productivity

# Get detailed app info
sakurajima-apps info postgres         # Shows ports, volumes, status, etc.
sakurajima-apps info obsidian         # Shows cask name, install status

# Install apps
sakurajima-apps install docker postgres
sakurajima-apps install brew obsidian

# Manage Docker containers
sakurajima-apps running               # Show running containers
sakurajima-apps stop postgres         # Stop a container
sakurajima-apps remove postgres       # Remove a container
sakurajima-apps logs postgres         # View container logs
```

**💡 Pro Tip: Shell Autocomplete**

The CLI includes smart autocomplete for zsh and bash:
- Type `sakurajima-apps install docker <TAB>` to see all Docker apps
- Type `sakurajima-apps install brew <TAB>` to see all Homebrew apps
- Type `sakurajima-apps stop <TAB>` to see only running containers
- All app names and descriptions are auto-completed from the catalog

After installation, restart your shell or run `source ~/.zshrc` to enable autocomplete.

## Available Docker Applications

### Databases
- **postgres** - PostgreSQL database server (port 5432)
- **mysql** - MySQL relational database (port 3306)
- **mongodb** - NoSQL document database (port 27017)
- **redis** - In-memory data structure store (port 6379)
- **elasticsearch** - Search and analytics engine (port 9200)

### Development
- **mailhog** - Email testing tool (SMTP: 1025, Web: 8025)
- **localstack** - Local AWS cloud stack (port 4566)

### Web
- **nginx** - High-performance web server (port 8080)

### Storage
- **minio** - S3-compatible object storage (API: 9000, Console: 9001)

### Messaging
- **rabbitmq** - Message broker (AMQP: 5672, Management: 15672)

All Docker containers:
- Are prefixed with `sakurajima-` for easy identification
- Use persistent volumes at `~/workspace/data/<app-name>`
- Auto-restart unless stopped manually
- Can be managed with standard Docker commands

## Available Homebrew Applications

### Productivity
- **obsidian** - Knowledge base and note-taking
- **notion** - All-in-one workspace
- **linear** - Issue tracking tool
- **rectangle-pro** - Window management (paid)
- **transmit** - File transfer client

### Development
- **postman** - API development platform
- **insomnia** - API client and design platform
- **tableplus** - Database management tool
- **fork** - Git client
- **fig** - Terminal autocomplete
- **warp** - Modern terminal

### Communication
- **slack** - Team communication platform
- **discord** - Voice, video, and text chat

### Entertainment
- **spotify** - Music streaming service
- **vlc** - Multimedia player

## Adding New Applications

To add new applications to the catalog, edit `~/setup/configs/apps-catalog.json`:

### Docker App Template

```json
{
  "name": "App Name",
  "slug": "app-slug",
  "image": "dockerhub/image:tag",
  "description": "Brief description",
  "category": "database|development|web|storage|messaging",
  "port": "host:container,host2:container2",
  "env": ["ENV_VAR=value"],
  "volume": "~/workspace/data/app:/container/path",
  "command": "optional-command-override"
}
```

### Homebrew App Template

```json
{
  "name": "App Name",
  "slug": "app-slug",
  "cask": "homebrew-cask-name",
  "description": "Brief description",
  "category": "productivity|development|communication|entertainment"
}
```

## Architecture

### Docker Container Management

When you install a Docker app:
1. The app is looked up in `configs/apps-catalog.json`
2. The `docker-install.sh` script is called with appropriate parameters
3. A container named `sakurajima-<app-slug>` is created
4. Data is persisted to `~/workspace/data/<app-slug>`
5. The container is configured to auto-restart unless manually stopped

### Integration with Existing Tools

- **lazydocker** - Use for TUI management of all containers
- **docker-compose** - Still available for complex multi-container setups (see `infra/`)
- **Raycast** - Provides quick access without leaving your workflow

## Best Practices

1. **Use the catalog for common services** - Pre-configured and optimized
2. **Keep data in ~/workspace/data** - Consistent backup and organization
3. **Use sakurajima-apps for management** - Consistent naming and tracking
4. **Check running containers regularly** - `sakurajima-apps running`
5. **Clean up unused containers** - `sakurajima-apps remove <app>`

## Troubleshooting

### Docker App Won't Start

```bash
# Check logs
sakurajima-apps logs <app-name>

# Check if port is already in use
lsof -i :<port-number>

# Remove and reinstall
sakurajima-apps remove <app-name>
sakurajima-apps install docker <app-name>
```

### Homebrew App Installation Fails

```bash
# Update Homebrew first
brew update

# Try installing directly to see detailed error
brew install --cask <cask-name>

# Check if app is already installed
brew list --cask
```

### Catalog Not Found

```bash
# Verify the catalog exists
ls -l ~/setup/configs/apps-catalog.json

# Re-run installer if missing
cd ~/setup && ./install.sh
```

## Related Documentation

- [Docker Installation](../scripts/docker-install.sh) - Lower-level Docker installer
- [Infrastructure](../infra/) - Docker Compose for complex setups
- [Raycast Workflows](../raycast/) - Raycast script integration

## Philosophy

This system follows Omakub's philosophy:
- **Curated over comprehensive** - Quality apps, not every app
- **Simple over complex** - Easy installation, sensible defaults
- **Documented over discovered** - Clear catalog, not guessing
- **Repeatable over custom** - Consistent setup across machines
