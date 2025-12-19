# 🏴 SAKURAJIMA — New Hire Checklist (0.1.0-alpha)

This checklist is for a new engineer to become productive immediately.

---

## A) Host Layer (Manual)

### A1) Time Machine
- External SSD encrypted APFS named `TimeMachineSSD`
- Time Machine enabled

### A2) Display
- 5K Monitor connected via USB-C/TB
- Running at Default for display (5120×2880), 60Hz

### A3) Audio
- Output: External DAC
- Audio MIDI Setup: 48kHz / 24-bit

### A4) Meetings system audio
- BlackHole installed
- Multi-Output `System+BlackHole` created
- Meeting input: BlackHole 2ch
- Meeting output: External DAC

---

## B) Dev Layer (Scripted)

### B1) Prereqs
Run:
- `xcode-select --install`
Apple Silicon:
- `softwareupdate --install-rosetta --agree-to-license`

### B2) Install
```bash
cd ~/setup
./install.sh
exec zsh
skr verify
```

Must pass.

⸻

C) Day-0 Manual Permissions

C1) Accessibility

Enable:
	•	AeroSpace
	•	Raycast

C2) Terminal font

Set to:
	•	FiraCode Nerd Font

C3) Raycast scripts

Add script directory:
	•	~/raycast/scripts/sakurajima

⸻

D) Create your first client

skr new <client> --name "<Your Name>" --email "<your@company.example>"
skr update


⸻

E) Start infra if needed

skr infra up


⸻

F) Final Acceptance
	•	Prompt shows client:<name> inside that client directory
	•	skr verify passes
	•	Raycast “Sakurajima:” commands appear
	•	AeroSpace hotkeys work
