## 1) The Two Layers

### Host Layer (manual)
- Time Machine SSD (APFS encrypted)
- Display correctness (5K Monitor via USB-C/TB)
- Audio correctness (External DAC)
- System-audio sharing in meetings (BlackHole Multi-Output)

### Dev Layer (scripted + verifiable)
- Brew dependencies
- Zsh + Starship
- Git + identity isolation by path
- SSH + per-client keys + aliases
- AeroSpace WM with generated client mapping
- Raycast script commands generated from clients
- Docker-first infra
- PROD guards

---

## 2) Day-0 Setup (Brand New Mac)

### 2.1 OS prerequisites
Run:
- `xcode-select --install`
Apple Silicon only:
- `softwareupdate --install-rosetta --agree-to-license`

### 2.2 Host Layer
Do these before any dev validation:

#### Time Machine SSD
- Disk Utility → Erase
  - Name: TimeMachineSSD
  - Format: APFS (Encrypted)
  - Scheme: GUID Partition Map
- System Settings → General → Time Machine → Add Backup Disk

#### Display (5K Monitor)
- Use USB-C/Thunderbolt
- System Settings → Displays:
  - Default for display (5120×2880)
  - 60Hz
  - Display P3

#### Audio (External DAC)
- Audio MIDI Setup:
  - 48kHz / 24-bit
  - Drift correction OFF
- System output: External DAC
- System volume: 100%

#### Meetings audio (BlackHole)
- Audio MIDI Setup → Create Multi-Output:
  - External DAC + BlackHole 2ch
  - Clock: External DAC
  - Name: System+BlackHole
- macOS Output: System+BlackHole
- Meeting Input: BlackHole 2ch
- Meeting Output: External DAC

---

## 3) Dev Layer Installation

### 3.1 Create repo
Repo must live at:
- `~/setup`

Create directory layout:
```bash
mkdir -p ~/setup/{configs,scripts,raycast,infra,docs}
cd ~/setup
```
Create files exactly as specified in the Master Document (0.1.0-alpha Parts).

3.2 Install
```
cd ~/setup
chmod +x install.sh scripts/* raycast/*.sh
./install.sh
exec zsh
skr verify
```

⸻

4) Manual Permissions (Unavoidable)

macOS blocks full automation here.

4.1 Accessibility

System Settings → Privacy & Security → Accessibility:
	•	Enable AeroSpace
	•	Enable Raycast

4.2 Terminal font (critical)

Terminal → Settings → Profiles → Text:
	•	Set to FiraCode Nerd Font

This is required for prompt glyphs.

4.3 Raycast Script Directory

Raycast → Settings → Extensions → Script Commands:
	•	Add Script Directory:
	•	~/raycast/scripts/sakurajima

⸻

5) Creating Clients (Meta-programming)

5.1 Create a client

skr new acme-corp --name "Jane Doe" --email "jane@acme.example"

This creates:
	•	~/workspace/clients/acme-corp
	•	SSH key: ~/.ssh/keys/gh-acme-corp_ed25519
	•	SSH aliases: github-acme-corp, gitlab-acme-corp
	•	Git identity isolated only inside that client path

5.2 Clone using aliases

GitHub:

git clone git@github-acme-corp:org/repo.git

GitLab:

git clone git@gitlab-acme-corp:group/repo.git


⸻

6) Window Manager (AeroSpace)

Regenerate mapping:

skr update

Client workspaces are generated from directories under:
	•	~/workspace/clients/*

Keys:
	•	alt-1..4 -> T/I/W/M
	•	ctrl-alt-cmd-1..9 -> clients (alphabetical)

⸻

7) Raycast

Regenerate scripts:

(Run `skr update` above)

Then Raycast search:
	•	“Sakurajima: Verify System”
	•	“Sakurajima: Focus ”
	•	“Sakurajima: Infra Up”

⸻

8) Local Infra (Docker-first)

Start infra:

`skr infra up`

Stop infra:

`skr infra down`

Wipe all data (destructive):

`docker compose -f ~/setup/infra/docker-compose.yml down -v`


⸻

9) Daily Workflow

Morning ritual
	•	skr verify
	•	skr infra up (if needed)

When adding a new client
	•	skr new <client>
	•	skr update

Weekly maintenance
	•	skr update

⸻

10) Troubleshooting

Prompt glyphs are broken
	•	Set Terminal font to a Nerd Font.

Raycast scripts not showing
	•	Ensure script directory added: ~/raycast/scripts/sakurajima
	•	Re-run: `skr update`

AeroSpace keys not working
	•	Enable Accessibility permission for AeroSpace.
	•	Re-run: `skr update`

Docker commands fail
	•	Open Docker Desktop once.
	•	Re-run: `skr infra up`
