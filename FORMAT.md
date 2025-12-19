# Format a Mac (True Clean Slate)

**Authoritative Guide** — Follow exactly.

## Before You Erase (Do NOT Skip)

### 1) Back up everything (mandatory)
*   Ensure Time Machine backup is complete or you’ve copied files elsewhere.
*   Verify the backup exists and is recent.

### 2) Sign out of Apple services
Do this **before** erasing to avoid activation locks.
1.  **System Settings** → **Apple ID**
2.  Sign out of **iCloud**
3.  **Apple ID** → **Media & Purchases** → Sign out
4.  **Messages** → Settings → Sign out
5.  **Find My** → Turn off for this Mac

### 3) Deauthorize licensed apps
*   **Music/TV**: Deauthorize this computer
*   Any software tied to machine activation

---

## Choose the Correct Erase Method

### A) Apple Silicon (M1/M2/M3) or Intel with T2 chip (Recommended)

1.  **System Settings** → **General** → **Transfer or Reset**
2.  Click **Erase All Content and Settings**
3.  Follow prompts (admin password required)
4.  Confirm erase

**What this does**:
*   Deletes all users and data
*   Resets system settings
*   Reinstalls macOS automatically
*   Removes activation locks correctly

### B) Older Intel Macs (No T2) or if A fails (Recovery)

1.  Shut down the Mac
2.  Power on and hold `⌘ + R`
3.  When Recovery loads, open **Disk Utility**
4.  Select **Macintosh HD** (top-level disk)
5.  Click **Erase**
    *   **Name**: Macintosh HD
    *   **Format**: APFS
    *   **Scheme**: GUID Partition Map
6.  Confirm erase
7.  Quit Disk Utility
8.  Choose **Reinstall macOS**
9.  Follow prompts

---

## First Boot After Formatting

1.  Choose Language and Region
2.  Connect to Wi-Fi
3.  Create a new admin user
4.  **Do NOT restore from Time Machine**
5.  **Apple ID**: You may skip now and sign in later (recommended for clean setup)

---

## After the Format (Critical)

### 1) Update macOS fully
*   **System Settings** → **General** → **Software Update**
*   Install all updates
*   Restart when finished

### 2) Confirm clean state
*   No previous users
*   No apps installed beyond macOS defaults
*   Fresh home directory

---

## You Are Now at TRUE ZERO

At this point:
*   The Mac is fully formatted
*   No residue remains
*   No accounts or configs are present
*   This is the correct starting point for a deterministic setup.

---

## Common Mistakes to Avoid
*   ❌ Restoring a full backup immediately
*   ❌ Using “cleaner” apps
*   ❌ Deleting system folders manually
*   ❌ Skipping sign-out before erase

---

## Final Confirmation

If you can answer yes to all:
*   [ ] macOS just reinstalled
*   [ ] New admin user created
*   [ ] No old files or apps present
*   [ ] System fully updated

✅ **Formatting is complete. You are starting from scratch.**
