#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
# 🏗️ SAKURAJIMA CHROMIUM BUILDER

info(){ printf "ℹ️  %s\n" "$*"; }
ok(){ printf "✅ %s\n" "$*"; }
warn(){ printf "⚠️  %s\n" "$*"; }
die(){ printf "❌ %s\n" "$*"; exit "${2:-1}"; }

BUILD_ROOT="$HOME/workspace/chromium_build"
DEPOT_TOOLS="$HOME/workspace/depot_tools"

# 1. Check depot_tools
if [[ ! -d "$DEPOT_TOOLS" ]]; then
  die "depot_tools not found at $DEPOT_TOOLS. Run 'skr verify' first."
fi

export PATH="$DEPOT_TOOLS:$PATH"

# 2. Prepare Directory
mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

info "Build Root: $BUILD_ROOT"

# 3. Fetch Code (if missing)
if [[ ! -d "src" ]]; then
  warn "Source not found. Fetching chromium... (This takes a long time)"
  warn "Ensure you have >40GB free space."
  fetch --nohistory chromium || die "fetch failed"
else
  ok "Source directory 'src' exists."
fi

cd src

# 4. Generate Build Files
if [[ ! -d "out/Default" ]]; then
  info "Generating build files (gn gen)..."
  gn gen out/Default || die "gn gen failed"
else
  ok "Build directory 'out/Default' exists."
fi

# 5. Compile
info "Starting build with autoninja..."
info "Target: chrome"
info "This will take HOURS. Go grab a coffee ☕."

autoninja -C out/Default chrome

ok "Build complete!"
echo
echo "to run:"
echo "  $BUILD_ROOT/src/out/Default/Chromium.app/Contents/MacOS/Chromium"
