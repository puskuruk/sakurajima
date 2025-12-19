# Building Chromium on macOS

This guide details how to build Chromium from source on macOS using `depot_tools`.

## Prerequisites

1.  **Xcode** (Full App): Required. Command Line Tools alone are **not sufficient**.
    - Install from **App Store** → Search "Xcode" → Install (~12GB)
    - After install: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
    - Accept license: `sudo xcodebuild -license accept`
2.  **depot_tools**: Required for fetching code and managing the build. (Included in Sakurajima at `~/workspace/depot_tools`).
3.  **Disk Space**: At least 40GB free (100GB recommended).
4.  **Time**: 1-5 hours depending on CPU.

## Automated Build

Run the helper script:

```bash
build-chromium
```

## Manual Instructions

### 1. Setup depot_tools

Ensure `depot_tools` is in your PATH.

```bash
export PATH="$HOME/workspace/depot_tools:$PATH"
```

### 2. Fetch the Code

Create a directory and fetch the source.

```bash
mkdir -p ~/workspace/chromium_build
cd ~/workspace/chromium_build
fetch chromium
```

### 3. Build

Enter the source directory and generate build files.

```bash
cd src
gn gen out/Default
```

Start the compilation.

```bash
autoninja -C out/Default chrome
```

### 4. Run

```bash
./out/Default/Chromium.app/Contents/MacOS/Chromium
```
