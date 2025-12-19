# 🌸 Sakurajima — Clean Install Guide (From Zero → Fully Functional)

**Version**: 0.1.0-alpha

> [!NOTE]
> This guide is for a brand-new or freshly wiped Mac. It covers manual host preparation and the scripted dev layer.

---

## PHASE 0 — STARTING ASSUMPTIONS

> [!TIP]
> Need to format first? See [FORMAT.md](FORMAT.md) for the authoritative clean slate guide.

You are starting with:
*   A brand-new or freshly wiped Mac
*   macOS Sonoma or newer
*   Administrator access
*   All Sakurajima files already prepared (or ready to clone)
*   **You will follow steps exactly in order**

---

## PHASE 1 — macOS BASE PREPARATION (HOST LAYER)

These steps configure the physical machine. They must be completed before any development validation.

### 1. Install Apple system prerequisites

#### 1.1 Xcode Command Line Tools
1.  Open Terminal
2.  Run: `xcode-select --install`
3.  Wait for installation to complete

> **Why**: Required for compilers, Git, Homebrew, and many native tools.

#### 1.2 Rosetta (Apple Silicon only)
1.  In Terminal, run: `softwareupdate --install-rosetta --agree-to-license`

> **Why**: Some tools still require x86 compatibility.

---

## PHASE 2 — BACKUP & DATA SAFETY (MANDATORY)

### 2. Configure Time Machine (External SSD)

#### 2.1 Prepare the disk
1.  Connect your external SSD
2.  Open **Disk Utility**
3.  Select the top-level disk (not a volume)
4.  Click **Erase**
5.  Set:
    *   **Name**: `TimeMachineSSD`
    *   **Format**: APFS (Encrypted)
    *   **Scheme**: GUID Partition Map
6.  Confirm erase
7.  Set a strong encryption password

#### 2.2 Enable Time Machine
1.  Open **System Settings**
2.  Go to **General** → **Time Machine**
3.  Click **Add Backup Disk**
4.  Select `TimeMachineSSD`
5.  Enable automatic backups
6.  (Recommended) Enable **Show Time Machine in menu bar**

> **Why**: You must be able to wipe and recover at any time with confidence.

---

## PHASE 3 — DISPLAY SETUP

### 3. Configure External Display (5K Monitor)

#### 3.1 Physical connection
*   Use USB-C / Thunderbolt
*   Do not use HDMI

#### 3.2 Display settings
1.  Open **System Settings** → **Displays**
2.  Select the external display
3.  Set:
    *   **Resolution**: Default for display (5120 × 2880)
    *   **Refresh rate**: 60 Hz
    *   **Color profile**: Display P3
4.  Disable or enable True Tone based on preference (OFF recommended for dev)

> **Why**: Ensures correct 2× scaling, sharp text, and no chroma subsampling.

---

## PHASE 4 — AUDIO & MEETINGS SETUP

### 4. Configure DAC (External DAC)

#### 4.1 Audio MIDI Setup
1.  Open **Audio MIDI Setup**
2.  Select your DAC
3.  Set:
    *   **Format**: 48,000 Hz
    *   **Bit depth**: 24-bit
    *   **Drift correction**: OFF

#### 4.2 System audio
1.  Open **System Settings** → **Sound**
2.  Set **Output** to your DAC
3.  Set system volume to 100%
4.  Control volume from the DAC hardware

### 5. Enable system-audio sharing for meetings (BlackHole)

#### 5.1 Create Multi-Output Device
1.  Open **Audio MIDI Setup**
2.  Click `+` → **Create Multi-Output Device**
3.  Enable:
    *   Your External DAC
    *   BlackHole 2ch
4.  Set **Clock Source** to your External DAC
5.  Rename device to: `System+BlackHole`

#### 5.2 How to use in meetings
*   **macOS Output**: `System+BlackHole`
*   **Meeting Microphone**: `BlackHole 2ch`
*   **Meeting Speakers**: Your External DAC

> **Why**: Allows sharing browser/system audio in meetings without feedback.

---

## PHASE 5 — CREATE THE SYSTEM REPOSITORY

### 6. Create the canonical setup directory

1.  Open Terminal
2.  Clone (or move) your repo to `~/setup`.

```bash
# Example
git clone <your-repo-url> ~/setup
```

> [!IMPORTANT]
> This system is path-dependent. Relocating `~/setup` is **not supported**.

---

## PHASE 6 — INSTALL THE DEV LAYER

### 7. Run the installer
1.  Open Terminal
2.  Navigate to `~/setup`
3.  Run the installer:

```bash
cd ~/setup
chmod +x install.sh
./install.sh
```

4.  Restart the shell session (`exec zsh`)
5.  Run system verification: `skr verify`

### 8. Verify installation success

The system must pass verification with no errors.

*   If verification fails: **Stop**. Fix the reported issue. Re-run `skr verify`.
*   **Do not continue** until verification passes.

---

## PHASE 7 — REQUIRED MANUAL PERMISSIONS (CRITICAL)

These cannot be automated by macOS.

### 9. Accessibility permissions
1.  Open **System Settings**
2.  Go to **Privacy & Security** → **Accessibility**
3.  Enable access for:
    *   **AeroSpace** (Window manager)
    *   **Raycast**

> **Why**: Required for window control and command execution.

### 10. Terminal font (required for prompt)
1.  Open Terminal
2.  Go to **Settings** → **Profiles** → **Text**
3.  Set font to: **FiraCode Nerd Font**
4.  Restart Terminal

> **Why**: Prompt glyphs will be broken without a Nerd Font.

### 11. Raycast setup
1.  Open **Raycast**
2.  Open Settings (⌘ `,`)
3.  Go to **Extensions** → **Script Commands**
4.  Click **Add Script Directory**
5.  Select: `~/raycast/scripts/sakurajima`
6.  Confirm Sakurajima commands appear in Raycast search

---

## PHASE 8 — FIRST-TIME WORKFLOW INITIALIZATION

### 12. Docker Desktop (first run)
1.  Launch **Docker Desktop**
2.  Complete initial setup
3.  Allow required system permissions
4.  Wait until Docker reports “Running”

> **Why**: Enables local infrastructure containers.

### 13. Create your first client

Create at least one client using the CLI.

```bash
skr new <client-name> --name "Your Name" --email "you@example.com"
```

This automatically:
*   Creates workspace directory
*   Generates SSH key
*   Configures Git identity isolation
*   Adds SSH host aliases

### 14. Regenerate dynamic systems

After creating clients, update the system to generate mappings:

```bash
skr update
```

> **Why**: Client mappings for AeroSpace and Raycast are derived from the filesystem.

---

## PHASE 9 — LOCAL INFRASTRUCTURE (OPTIONAL)

### 15. Start local infrastructure (if needed)

Start Docker-based services (Mongo, Postgres, Redis):

```bash
skr infra up
```

Stop them:

```bash
skr infra down
```

---

## PHASE 10 — FINAL ACCEPTANCE CHECK

You are fully installed when all are true:
*   [ ] `skr verify` passes
*   [ ] Terminal prompt shows client context inside client directories
*   [ ] Window manager shortcuts work (e.g., `Alt-h/j/k/l`)
*   [ ] Raycast "Sakurajima" commands are available
*   [ ] Git identity changes correctly per client
*   [ ] SSH keys are isolated per client
*   [ ] Docker infrastructure starts and stops cleanly
*   [ ] Time Machine backups are active

---

## FINAL STATE

You now have:
*   A deterministic development machine
*   Strong production safety guarantees
*   Zero client identity leakage
*   A system you can wipe and rebuild at any time

✅ **Clean installation complete.**
