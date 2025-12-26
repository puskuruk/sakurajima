# Sakurajima Installation

## Prerequisites

```bash
xcode-select --install
softwareupdate --install-rosetta --agree-to-license  # Apple Silicon only
```

## Install

```bash
git clone <repo> ~/setup
cd ~/setup && ./install.sh
exec zsh
skr verify
```

## Manual Permissions

1. **Accessibility**: System Settings → Privacy & Security → Accessibility → Enable AeroSpace, Raycast
2. **Terminal Font**: Set to FiraCode Nerd Font
3. **Raycast**: Settings → Script Commands → Add `~/raycast/scripts/sakurajima`

## First Client

```bash
skr new <client-name>
```

## Verify

```bash
skr verify
skr help
```

See [FORMAT.md](FORMAT.md) if you need to wipe the Mac first.
