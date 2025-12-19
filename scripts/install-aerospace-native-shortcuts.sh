#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

 # 🏴 SAKURAJIMA — AEROSPACE NATIVE SHORTCUTS INSTALLER
 # Installs window-snap actions that are intended to be triggered by macOS Shortcuts.app hotkeys.
 #
 # Why:
 # - AeroSpace does NOT support "left-half / quarter / center / restore" commands natively.
 # - Its `resize` command is incremental only (width/height/smart) and requires +/-number.
 #
 # Output:
 #   ~/.local/share/sakurajima/aerospace-actions/*.sh
 #   ~/.local/share/sakurajima/aerospace-actions/_lib.js (JXA helper)
 
 ok(){ printf "✅ %s\n" "$*"; }
 info(){ printf "ℹ️  %s\n" "$*"; }
 warn(){ printf "⚠️  %s\n" "$*"; }
 die(){ printf "❌ %s\n" "$*"; exit "${2:-2}"; }
 
 [[ "$(uname -s)" == "Darwin" ]] || die "macOS only."
 
 ROOT="${HOME}/.local/share/sakurajima"
 ACTIONS_DIR="${ROOT}/aerospace-actions"
 STATE_DIR="${ROOT}/window-state"
 
 mkdir -p "$ACTIONS_DIR" "$STATE_DIR"
 
 # JXA library: get visible frame + set front window bounds + save/restore
 cat > "${ACTIONS_DIR}/_lib.js" <<'JXA'
 ObjC.import('Cocoa');
 
 function frontmostAppName() {
   const se = Application('System Events');
   se.includeStandardAdditions = true;
   const p = se.applicationProcesses.whose({ frontmost: { '=': true } })[0];
   return p ? p.name() : null;
 }
 
 function visibleFrame() {
   const screen = $.NSScreen.mainScreen;
   if (!screen) throw new Error("No main screen");
   const f = screen.visibleFrame;
   return { x: f.origin.x, y: f.origin.y, w: f.size.width, h: f.size.height };
 }
 
 function getFrontWindowBounds(appName) {
   const se = Application('System Events');
   const app = se.applicationProcesses.byName(appName);
   const win = app.windows[0];
   const pos = win.position();
   const size = win.size();
   return { x: pos[0], y: pos[1], w: size[0], h: size[1] };
 }
 
 function setFrontWindowBounds(appName, rect) {
   const se = Application('System Events');
   const app = se.applicationProcesses.byName(appName);
   const win = app.windows[0];
 
   // Important: set position before size tends to be more stable across apps
   win.position = [Math.round(rect.x), Math.round(rect.y)];
   win.size = [Math.round(rect.w), Math.round(rect.h)];
 }
 
 function readJSON(path) {
   const fm = $.NSFileManager.defaultManager;
   if (!fm.fileExistsAtPath(path)) return null;
   const data = $.NSData.dataWithContentsOfFile(path);
   if (!data) return null;
   const str = $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js;
   return JSON.parse(str);
 }
 
 function writeJSON(path, obj) {
   const str = JSON.stringify(obj);
   const ns = $.NSString.alloc.initWithUTF8String(str);
   ns.writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
 }
 
 function run(argv) {
   // argv: action, statePath, [param...]
   const action = argv[0];
   const statePath = argv[1];
 
   const appName = frontmostAppName();
   if (!appName) throw new Error("No frontmost app");
 
   // Capture current bounds (for restore)
   const cur = getFrontWindowBounds(appName);
   writeJSON(statePath, { appName, bounds: cur });
 
   const vf = visibleFrame();
 
   // Basic paddings (tweak if you want)
   const pad = 0;
 
   function apply(r) { setFrontWindowBounds(appName, r); }
 
   switch (action) {
     case "left-half":
       return apply({ x: vf.x + pad, y: vf.y + pad, w: (vf.w/2) - (pad*2), h: vf.h - (pad*2) });
     case "right-half":
       return apply({ x: vf.x + (vf.w/2) + pad, y: vf.y + pad, w: (vf.w/2) - (pad*2), h: vf.h - (pad*2) });
     case "top-half":
       return apply({ x: vf.x + pad, y: vf.y + pad, w: vf.w - (pad*2), h: (vf.h/2) - (pad*2) });
     case "bottom-half":
       return apply({ x: vf.x + pad, y: vf.y + (vf.h/2) + pad, w: vf.w - (pad*2), h: (vf.h/2) - (pad*2) });
 
     case "top-left":
       return apply({ x: vf.x + pad, y: vf.y + pad, w: (vf.w/2) - (pad*2), h: (vf.h/2) - (pad*2) });
     case "top-right":
       return apply({ x: vf.x + (vf.w/2) + pad, y: vf.y + pad, w: (vf.w/2) - (pad*2), h: (vf.h/2) - (pad*2) });
     case "bottom-left":
       return apply({ x: vf.x + pad, y: vf.y + (vf.h/2) + pad, w: (vf.w/2) - (pad*2), h: (vf.h/2) - (pad*2) });
     case "bottom-right":
       return apply({ x: vf.x + (vf.w/2) + pad, y: vf.y + (vf.h/2) + pad, w: (vf.w/2) - (pad*2), h: (vf.h/2) - (pad*2) });
 
     case "maximize":
       return apply({ x: vf.x + pad, y: vf.y + pad, w: vf.w - (pad*2), h: vf.h - (pad*2) });
 
     case "maximize-height": {
       // keep current x/w, expand y/h to full visible height
       return apply({ x: cur.x, y: vf.y + pad, w: cur.w, h: vf.h - (pad*2) });
     }
 
     case "center": {
       // keep current size, center inside visible frame
       const nx = vf.x + ((vf.w - cur.w) / 2);
       const ny = vf.y + ((vf.h - cur.h) / 2);
       return apply({ x: nx, y: ny, w: cur.w, h: cur.h });
     }
 
     case "resize": {
       // argv[2] = deltaPx (positive or negative), applies to both width and height from center
       const delta = parseInt(argv[2], 10);
       if (isNaN(delta) || delta === 0) throw new Error("resize requires non-zero integer deltaPx");
       const nw = Math.max(200, cur.w + delta);
       const nh = Math.max(120, cur.h + delta);
       const nx = cur.x - ((nw - cur.w) / 2);
       const ny = cur.y - ((nh - cur.h) / 2);
       return apply({ x: nx, y: ny, w: nw, h: nh });
     }
 
     case "restore": {
       const st = readJSON(statePath);
       if (!st || !st.bounds) return;
       // restore only if same frontmost app; avoids restoring random app state
       if (st.appName !== appName) return;
       return apply(st.bounds);
     }
 
     default:
       throw new Error("Unknown action: " + action);
   }
 }
 
JXA
 
chmod +x "${ACTIONS_DIR}/_lib.js"
 
write_action() {
  local name="$1"
  local action="$2"
  cat > "${ACTIONS_DIR}/${name}.sh" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=\$'\\n\\t'

STATE_DIR="\${HOME}/.local/share/sakurajima/window-state"
mkdir -p "\$STATE_DIR"

win_id=""
if command -v aerospace >/dev/null 2>&1; then
  win_id="\$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null || true)"
fi
[[ -n "\$win_id" ]] || win_id="frontmost"

state="\${STATE_DIR}/\${win_id}.json"

exec osascript -l JavaScript "\${HOME}/.local/share/sakurajima/aerospace-actions/_lib.js" "${action}" "\$state" "\${3:-}"
EOF
  chmod +x "${ACTIONS_DIR}/${name}.sh"
}
 
# Halves
write_action "left-half"   "left-half"
write_action "right-half"  "right-half"
write_action "top-half"    "top-half"
write_action "bottom-half" "bottom-half"
 
# Corners
write_action "top-left"     "top-left"
write_action "top-right"    "top-right"
write_action "bottom-left"  "bottom-left"
write_action "bottom-right" "bottom-right"
 
# Size / position
write_action "maximize"        "maximize"
write_action "maximize-height" "maximize-height"
write_action "center"          "center"
write_action "restore"         "restore"
 
# Incremental size (maps to your “smaller/larger”)
cat > "${ACTIONS_DIR}/smaller.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
exec "${HOME}/.local/share/sakurajima/aerospace-actions/resize.sh" -80
EOF
chmod +x "${ACTIONS_DIR}/smaller.sh"

cat > "${ACTIONS_DIR}/larger.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
exec "${HOME}/.local/share/sakurajima/aerospace-actions/resize.sh" 80
EOF
chmod +x "${ACTIONS_DIR}/larger.sh"

cat > "${ACTIONS_DIR}/resize.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
delta="${1:-}"
[[ -n "$delta" ]] || { echo "deltaPx required"; exit 2; }

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

cat > "${ACTIONS_DIR}/open-terminal.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Deterministic: bring Terminal to foreground without requiring Automation permissions.
open -a Terminal

# Best-effort: open a new window/tab. This may require Automation permission.
osascript >/dev/null 2>&1 <<'OSA' || true
tell application "Terminal"
  activate
  do script ""
end tell
OSA
EOF
chmod +x "${ACTIONS_DIR}/open-terminal.sh"
 
MAP_FILE="${ACTIONS_DIR}/SHORTCUTS_MAP.txt"
info "Writing native shortcuts map: $MAP_FILE"
cat > "$MAP_FILE" <<'EOF'
SAKURAJIMA — macOS Native Shortcuts (Shortcuts.app)

Create shortcuts in Shortcuts.app.
Each shortcut:
  - Add action: “Run Shell Script”
  - Shell: /bin/zsh
  - Script: exactly one line pointing to the matching file below.

Files live under:
  ~/.local/share/sakurajima/aerospace-actions/

HALVES (⌃⌥):
  ⌃⌥←  → left-half.sh
  ⌃⌥→  → right-half.sh
  ⌃⌥↑  → top-half.sh
  ⌃⌥↓  → bottom-half.sh

CORNERS (⌃⌥):
  ⌃⌥U  → top-left.sh
  ⌃⌥I  → top-right.sh
  ⌃⌥J  → bottom-left.sh
  ⌃⌥K  → bottom-right.sh

WINDOW SIZE / POSITION (⌃⌥):
  ⌃⌥↩  → maximize.sh
  ⌃⌥⇧↑ → maximize-height.sh
  ⌃⌥-  → smaller.sh
  ⌃⌥=  → larger.sh
  ⌃⌥C  → center.sh
  ⌃⌥⌫  → restore.sh

OPEN:
  ⌃⌥T  → open-terminal.sh

VERIFY (run any of these from Terminal):
  ~/.local/share/sakurajima/aerospace-actions/left-half.sh
EOF
 ok "Map written"
 
 ok "Installed actions into: ${ACTIONS_DIR}"
 info "Next: create macOS Shortcuts that run these scripts and assign hotkeys."
 info "Actions list:"
 ls -1 "${ACTIONS_DIR}" | sed 's/^/  - /'