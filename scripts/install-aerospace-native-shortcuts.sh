#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# =============================================================================
# SAKURAJIMA NATIVE SHORTCUTS INSTALLER
# Version: 0.2.0
# =============================================================================
# Installs window-snap actions triggered by macOS Shortcuts.app hotkeys.
#
# Why this exists:
# - AeroSpace handles tiling but doesn't have built-in snap-to-half/quarter
# - These JXA scripts provide Rectangle-style window snapping
# - Works alongside AeroSpace for the best of both worlds
#
# Output:
#   ~/.local/share/sakurajima/aerospace-actions/*.sh
#   ~/.local/share/sakurajima/aerospace-actions/_lib.js (JXA helper)
# =============================================================================

# Output helpers
ok(){ printf "\033[32m✓\033[0m %s\n" "$*"; }
info(){ printf "\033[1m→\033[0m %s\n" "$*"; }
warn(){ printf "\033[33m⚠\033[0m %s\n" "$*"; }
die(){ printf "\033[31m✗\033[0m %s\n" "$*"; exit "${2:-1}"; }

[[ "$(uname -s)" == "Darwin" ]] || die "macOS only."

# Directories
ROOT="${HOME}/.local/share/sakurajima"
ACTIONS_DIR="${ROOT}/aerospace-actions"
STATE_DIR="${ROOT}/window-state"

mkdir -p "$ACTIONS_DIR" "$STATE_DIR"

echo
info "Installing Sakurajima Native Shortcuts..."
echo

# =============================================================================
# JXA LIBRARY
# =============================================================================
# Core JavaScript for Automation (JXA) functions for window manipulation

cat > "${ACTIONS_DIR}/_lib.js" <<'JXA'
ObjC.import('Cocoa');

// Get the frontmost application name
function frontmostAppName() {
  const se = Application('System Events');
  se.includeStandardAdditions = true;
  const p = se.applicationProcesses.whose({ frontmost: { '=': true } })[0];
  return p ? p.name() : null;
}

// Get the visible frame of the main screen (excludes menu bar and dock)
function visibleFrame() {
  const screen = $.NSScreen.mainScreen;
  if (!screen) throw new Error("No main screen");
  const f = screen.visibleFrame;
  return { x: f.origin.x, y: f.origin.y, w: f.size.width, h: f.size.height };
}

// Get bounds of the frontmost window
function getFrontWindowBounds(appName) {
  const se = Application('System Events');
  const app = se.applicationProcesses.byName(appName);
  const win = app.windows[0];
  const pos = win.position();
  const size = win.size();
  return { x: pos[0], y: pos[1], w: size[0], h: size[1] };
}

// Set bounds of the frontmost window
function setFrontWindowBounds(appName, rect) {
  const se = Application('System Events');
  const app = se.applicationProcesses.byName(appName);
  const win = app.windows[0];
  // Set position first, then size (more stable across apps)
  win.position = [Math.round(rect.x), Math.round(rect.y)];
  win.size = [Math.round(rect.w), Math.round(rect.h)];
}

// Read JSON from file
function readJSON(path) {
  const fm = $.NSFileManager.defaultManager;
  if (!fm.fileExistsAtPath(path)) return null;
  const data = $.NSData.dataWithContentsOfFile(path);
  if (!data) return null;
  const str = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js;
  return JSON.parse(str);
}

// Write JSON to file
function writeJSON(path, obj) {
  const str = JSON.stringify(obj);
  const ns = $.NSString.alloc.initWithUTF8String(str);
  ns.writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
}

// Main entry point
function run(argv) {
  const action = argv[0];
  const statePath = argv[1];

  const appName = frontmostAppName();
  if (!appName) throw new Error("No frontmost app");

  // Capture current bounds (for restore)
  const cur = getFrontWindowBounds(appName);
  writeJSON(statePath, { appName, bounds: cur });

  const vf = visibleFrame();

  function apply(r) { setFrontWindowBounds(appName, r); }

  switch (action) {
    // Halves
    case "left-half":
      return apply({ x: vf.x, y: vf.y, w: vf.w / 2, h: vf.h });
    case "right-half":
      return apply({ x: vf.x + vf.w / 2, y: vf.y, w: vf.w / 2, h: vf.h });
    case "top-half":
      return apply({ x: vf.x, y: vf.y, w: vf.w, h: vf.h / 2 });
    case "bottom-half":
      return apply({ x: vf.x, y: vf.y + vf.h / 2, w: vf.w, h: vf.h / 2 });

    // Quarters (corners)
    case "top-left":
      return apply({ x: vf.x, y: vf.y, w: vf.w / 2, h: vf.h / 2 });
    case "top-right":
      return apply({ x: vf.x + vf.w / 2, y: vf.y, w: vf.w / 2, h: vf.h / 2 });
    case "bottom-left":
      return apply({ x: vf.x, y: vf.y + vf.h / 2, w: vf.w / 2, h: vf.h / 2 });
    case "bottom-right":
      return apply({ x: vf.x + vf.w / 2, y: vf.y + vf.h / 2, w: vf.w / 2, h: vf.h / 2 });

    // Thirds
    case "left-third":
      return apply({ x: vf.x, y: vf.y, w: vf.w / 3, h: vf.h });
    case "center-third":
      return apply({ x: vf.x + vf.w / 3, y: vf.y, w: vf.w / 3, h: vf.h });
    case "right-third":
      return apply({ x: vf.x + 2 * vf.w / 3, y: vf.y, w: vf.w / 3, h: vf.h });

    // Two-thirds
    case "left-two-thirds":
      return apply({ x: vf.x, y: vf.y, w: 2 * vf.w / 3, h: vf.h });
    case "right-two-thirds":
      return apply({ x: vf.x + vf.w / 3, y: vf.y, w: 2 * vf.w / 3, h: vf.h });

    // Full and centered
    case "maximize":
      return apply({ x: vf.x, y: vf.y, w: vf.w, h: vf.h });

    case "almost-maximize": {
      const margin = 20;
      return apply({
        x: vf.x + margin,
        y: vf.y + margin,
        w: vf.w - 2 * margin,
        h: vf.h - 2 * margin
      });
    }

    case "maximize-height":
      return apply({ x: cur.x, y: vf.y, w: cur.w, h: vf.h });

    case "maximize-width":
      return apply({ x: vf.x, y: cur.y, w: vf.w, h: cur.h });

    case "center": {
      const nx = vf.x + (vf.w - cur.w) / 2;
      const ny = vf.y + (vf.h - cur.h) / 2;
      return apply({ x: nx, y: ny, w: cur.w, h: cur.h });
    }

    case "center-half": {
      // Center with half screen width
      const w = vf.w / 2;
      const h = vf.h;
      const nx = vf.x + (vf.w - w) / 2;
      return apply({ x: nx, y: vf.y, w, h });
    }

    // Resize
    case "resize": {
      const delta = parseInt(argv[2], 10);
      if (isNaN(delta) || delta === 0) throw new Error("resize requires non-zero integer");
      const nw = Math.max(200, cur.w + delta);
      const nh = Math.max(120, cur.h + delta);
      const nx = cur.x - (nw - cur.w) / 2;
      const ny = cur.y - (nh - cur.h) / 2;
      return apply({ x: nx, y: ny, w: nw, h: nh });
    }

    // Restore previous size/position
    case "restore": {
      const st = readJSON(statePath);
      if (!st || !st.bounds) return;
      if (st.appName !== appName) return;
      return apply(st.bounds);
    }

    default:
      throw new Error("Unknown action: " + action);
  }
}
JXA

chmod +x "${ACTIONS_DIR}/_lib.js"
ok "Created JXA library"

# =============================================================================
# ACTION SCRIPT GENERATOR
# =============================================================================

write_action() {
  local name="$1"
  local action="$2"
  local extra_arg="${3:-}"

  cat > "${ACTIONS_DIR}/${name}.sh" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=\$'\\n\\t'

STATE_DIR="\${HOME}/.local/share/sakurajima/window-state"
mkdir -p "\$STATE_DIR"

# Get window ID from AeroSpace if available
win_id=""
if command -v aerospace >/dev/null 2>&1; then
  win_id="\$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null || true)"
fi
[[ -n "\$win_id" ]] || win_id="frontmost"

state="\${STATE_DIR}/\${win_id}.json"

exec osascript -l JavaScript "\${HOME}/.local/share/sakurajima/aerospace-actions/_lib.js" "${action}" "\$state" ${extra_arg:+"\"$extra_arg\""}
EOF
  chmod +x "${ACTIONS_DIR}/${name}.sh"
}

# Halves
write_action "left-half" "left-half"
write_action "right-half" "right-half"
write_action "top-half" "top-half"
write_action "bottom-half" "bottom-half"
ok "Created half-screen actions"

# Quarters (corners)
write_action "top-left" "top-left"
write_action "top-right" "top-right"
write_action "bottom-left" "bottom-left"
write_action "bottom-right" "bottom-right"
ok "Created quarter-screen actions"

# Thirds
write_action "left-third" "left-third"
write_action "center-third" "center-third"
write_action "right-third" "right-third"
write_action "left-two-thirds" "left-two-thirds"
write_action "right-two-thirds" "right-two-thirds"
ok "Created third-screen actions"

# Size / position
write_action "maximize" "maximize"
write_action "almost-maximize" "almost-maximize"
write_action "maximize-height" "maximize-height"
write_action "maximize-width" "maximize-width"
write_action "center" "center"
write_action "center-half" "center-half"
write_action "restore" "restore"
ok "Created size/position actions"

# Resize scripts
cat > "${ACTIONS_DIR}/resize.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

delta="${1:-}"
[[ -n "$delta" ]] || { echo "Usage: resize.sh <delta>"; exit 1; }

STATE_DIR="${HOME}/.local/share/sakurajima/window-state"
mkdir -p "$STATE_DIR"

win_id=""
if command -v aerospace >/dev/null 2>&1; then
  win_id="$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null || true)"
fi
[[ -n "$win_id" ]] || win_id="frontmost"

state="${STATE_DIR}/${win_id}.json"

exec osascript -l JavaScript "${HOME}/.local/share/sakurajima/aerospace-actions/_lib.js" "resize" "$state" "$delta"
EOF
chmod +x "${ACTIONS_DIR}/resize.sh"

cat > "${ACTIONS_DIR}/smaller.sh" <<'EOF'
#!/usr/bin/env bash
exec "${HOME}/.local/share/sakurajima/aerospace-actions/resize.sh" -80
EOF
chmod +x "${ACTIONS_DIR}/smaller.sh"

cat > "${ACTIONS_DIR}/larger.sh" <<'EOF'
#!/usr/bin/env bash
exec "${HOME}/.local/share/sakurajima/aerospace-actions/resize.sh" 80
EOF
chmod +x "${ACTIONS_DIR}/larger.sh"
ok "Created resize actions"

# Open Terminal
cat > "${ACTIONS_DIR}/open-terminal.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Open Terminal and create new window
open -a Terminal
osascript >/dev/null 2>&1 <<'OSA' || true
tell application "Terminal"
  activate
  do script ""
end tell
OSA
EOF
chmod +x "${ACTIONS_DIR}/open-terminal.sh"
ok "Created open-terminal action"

# =============================================================================
# SHORTCUTS MAP (Documentation)
# =============================================================================

MAP_FILE="${ACTIONS_DIR}/SHORTCUTS_MAP.txt"
cat > "$MAP_FILE" <<'EOF'
================================================================================
SAKURAJIMA NATIVE SHORTCUTS
================================================================================

These scripts provide Rectangle-style window snapping that works alongside
AeroSpace. Create shortcuts in Shortcuts.app to bind hotkeys.

SETUP:
  1. Open Shortcuts.app
  2. Create a new shortcut for each action
  3. Add action: "Run Shell Script"
  4. Shell: /bin/bash
  5. Script: ~/.local/share/sakurajima/aerospace-actions/<action>.sh
  6. Assign keyboard shortcut in shortcut settings

================================================================================
RECOMMENDED SHORTCUTS (matches Rectangle defaults)
================================================================================

HALVES (ctrl-option):
  ┌─────────────────┬──────────────────────────────────┐
  │ Shortcut        │ Action                           │
  ├─────────────────┼──────────────────────────────────┤
  │ ⌃⌥←             │ left-half.sh                     │
  │ ⌃⌥→             │ right-half.sh                    │
  │ ⌃⌥↑             │ top-half.sh                      │
  │ ⌃⌥↓             │ bottom-half.sh                   │
  └─────────────────┴──────────────────────────────────┘

QUARTERS (ctrl-option):
  ┌─────────────────┬──────────────────────────────────┐
  │ Shortcut        │ Action                           │
  ├─────────────────┼──────────────────────────────────┤
  │ ⌃⌥U             │ top-left.sh                      │
  │ ⌃⌥I             │ top-right.sh                     │
  │ ⌃⌥J             │ bottom-left.sh                   │
  │ ⌃⌥K             │ bottom-right.sh                  │
  └─────────────────┴──────────────────────────────────┘

THIRDS (ctrl-option-cmd):
  ┌─────────────────┬──────────────────────────────────┐
  │ Shortcut        │ Action                           │
  ├─────────────────┼──────────────────────────────────┤
  │ ⌃⌥⌘←            │ left-third.sh                    │
  │ ⌃⌥⌘→            │ right-third.sh                   │
  │ ⌃⌥⌘↓            │ center-third.sh                  │
  │ ⌃⌥⌘⇧←           │ left-two-thirds.sh               │
  │ ⌃⌥⌘⇧→           │ right-two-thirds.sh              │
  └─────────────────┴──────────────────────────────────┘

SIZE & POSITION (ctrl-option):
  ┌─────────────────┬──────────────────────────────────┐
  │ Shortcut        │ Action                           │
  ├─────────────────┼──────────────────────────────────┤
  │ ⌃⌥⏎             │ maximize.sh                      │
  │ ⌃⌥⇧⏎            │ almost-maximize.sh               │
  │ ⌃⌥⇧↑            │ maximize-height.sh               │
  │ ⌃⌥⇧→            │ maximize-width.sh                │
  │ ⌃⌥C             │ center.sh                        │
  │ ⌃⌥⇧C            │ center-half.sh                   │
  │ ⌃⌥-             │ smaller.sh                       │
  │ ⌃⌥=             │ larger.sh                        │
  │ ⌃⌥⌫             │ restore.sh                       │
  └─────────────────┴──────────────────────────────────┘

UTILITIES:
  ┌─────────────────┬──────────────────────────────────┐
  │ Shortcut        │ Action                           │
  ├─────────────────┼──────────────────────────────────┤
  │ ⌃⌥T             │ open-terminal.sh                 │
  └─────────────────┴──────────────────────────────────┘

================================================================================
AEROSPACE BINDINGS (already configured in aerospace.toml)
================================================================================

These are handled by AeroSpace directly, not via Shortcuts.app:

FOCUS (alt + vim keys):
  ⌥H/J/K/L          Focus window left/down/up/right

MOVE (alt-shift + vim keys):
  ⌥⇧H/J/K/L         Move window left/down/up/right

SWAP (ctrl-alt + vim keys):
  ⌃⌥H/J/K/L         Swap window with neighbor

RESIZE MODE:
  ⌥R                Enter resize mode
  H/J/K/L           Resize in that direction
  ESC               Exit resize mode

LAYOUT:
  ⌥/                Toggle tile orientation
  ⌥,                Toggle accordion orientation
  ⌥⇧Space           Toggle floating/tiling
  ⌥F                Toggle fullscreen
  ⌥⇧F               Toggle macOS native fullscreen

WORKSPACES:
  ⌥1/2/3/4          Switch to workspace T/I/W/M
  ⌥⇧1/2/3/4         Move window to workspace T/I/W/M
  ⌥`                Toggle last two workspaces
  ⌥[/]              Previous/next workspace

CLIENT WORKSPACES:
  ⌃⌥⌘1-9            Switch to client workspace
  ⌃⌥⌘⇧1-9           Move window to client workspace

MONITORS:
  ⌃⌥←/→/↑/↓         Focus monitor in direction
  ⌃⌥⇧←/→/↑/↓        Move window to monitor
  ⌃⌥⌘←/→            Move workspace to monitor

================================================================================
TESTING

Run any script directly to test:
  ~/.local/share/sakurajima/aerospace-actions/left-half.sh
================================================================================
EOF

ok "Created shortcuts map: $MAP_FILE"

# =============================================================================
# SUMMARY
# =============================================================================

echo
ok "Native shortcuts installed to: ${ACTIONS_DIR}"
echo
info "To enable shortcuts:"
info "  1. Open Shortcuts.app"
info "  2. Create shortcuts pointing to the scripts above"
info "  3. Assign keyboard shortcuts in each shortcut's settings"
echo
info "Reference: ${MAP_FILE}"
echo
