# 🌐 I2P Daemon GUI

<div align="center">

<img src="imagegit.png" alt="I2P Daemon GUI" width="280"/>

</div>

<div align="center">


![I2P-GUI App](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.7+-orange.svg)
![Version](https://img.shields.io/badge/Version-2.61.0-green.svg)
![I2P](https://img.shields.io/badge/I2P-2.61.0-purple.svg)
![License](https://img.shields.io/badge/License-BSD--3--Clause-yellow.svg)

**Modern GUI for managing I2P daemon on macOS with full internationalization**

[![Download](https://img.shields.io/badge/📥%20Download-I2P%20Daemon%20GUI.app-brightgreen.svg)](https://github.com/MetanoicArmor/gui-i2pd/releases/download/v2.61.0/I2P-Daemon-GUI-2.61.0.zip)
[![Build Status](https://img.shields.io/badge/🔧%20Build-Passing-success.svg)](https://github.com/MetanoicArmor/gui-i2pd/actions)

</div>

---

## 🌐 Language / Язык

<div align="center">

### 🇺🇸 **English Documentation**
[![English README](https://img.shields.io/badge/📖%20English%20README-blue.svg)](README.md)

**Full English documentation with screenshots and features**

### 🇷🇺 **Русская документация**
[![Русский README](https://img.shields.io/badge/📖%20Русский%20README-red.svg)](README_RU.md)

**Полная русская документация со скриншотами и функциями**

</div>

---

## 🎯 Description

**I2P Daemon GUI** is an elegant native macOS application that allows you to easily manage I2P daemon through a modern SwiftUI interface. No more command line - all management in just a few clicks!

### ✨ **Key Features:**
- 🖥️ **Modern SwiftUI interface** with adaptive theme
- 🌐 **Full internationalization** (Russian/English) with smart restart
- 🚀 **One-click start/stop** daemon management
- 📊 **Real-time monitoring** of daemon status
- 📋 **Comprehensive statistics** of server and network
- ⚙️ **Interactive settings** with port and bandwidth management
- 🔧 **Auto-start via LaunchAgent** for automatic startup on system login
- 📝 **Detailed logging** of all operations  
- 🎛️ **System tray** with daemon state indicators and quick controls
- 🔄 **Smart exit** with proper daemon shutdown (Cmd+Q, tray, language change)
- 🌐 **Dynamic configuration reading** with automatic settings parsing
- 📱 **Start minimized** - application starts in tray without showing window
- 🛠️ **Built-in Tools module** - comprehensive set of I2P utilities with interactive terminal

---

## 📥 Download and Installation

### 🎯 **Quick Start (recommended):**

1. **📥 Download the ready application:**
   ```bash
   # Direct link to .app ZIP archive
   curl -L https://github.com/MetanoicArmor/gui-i2pd/releases/download/v2.61.0/I2P-Daemon-GUI-2.61.0.zip -o I2P-Daemon-GUI-2.61.0.zip
   ```

2. **📁 Extract and install:**
   ```bash
   unzip I2P-Daemon-GUI-2.61.0.zip
   mv "I2P Daemon GUI.app" /Applications/
   ```

3. **🚀 Launch the application:**
   ```bash
   open "/Applications/I2P Daemon GUI.app"
   ```

### 🍺 **Homebrew: arm64 + Intel:**

The cask automatically chooses the matching ZIP for your architecture (Apple Silicon or Intel) from the release assets.

Install / upgrade:

```bash
brew install --cask metanoicarmor/i2pd-gui/i2pd-gui
brew upgrade --cask i2pd-gui
```

The cask has a `postflight` step that automatically runs `xattr -dr com.apple.quarantine` on the installed `.app`, so on most systems the app opens without any extra action.

If macOS still reports the app as **“damaged”** (Gatekeeper / quarantine on a non‑notarized download), run manually:

```bash
xattr -dr com.apple.quarantine "/Applications/I2P Daemon GUI.app"
```

Recent macOS versions may not offer **“Open Anyway”** in System Settings for this case (that flow targets *unidentified developer*, not *damaged*). The proper long‑term fix is a Developer ID signature + Apple notarization.

**Maintainers:** `brew` reads the cask from [MetanoicArmor/homebrew-i2pd-gui](https://github.com/MetanoicArmor/homebrew-i2pd-gui), not from this repo. After you upload new release ZIPs, update `Casks/i2pd-gui.rb` there (version and `sha256` per architecture). The `Casks/` file here is only a reference copy.

### 📋 **System Requirements:**
- **macOS**: 14.0 or newer
- **Processor**: Intel x64 or Apple Silicon (M1/M2/M3/M4)
- **Memory**: 100+ MB free RAM
- **Disk Space**: 35+ MB

---

## 🎨 Interface and Features

### 📸 **Screenshots (English UI):**

<img src="screenshots/screenshot1_en.png" alt="I2P GUI Main Interface" width="695" />
*Main window: daemon status, stats, and controls*

![I2P GUI Settings](screenshots/screenshot2_en.png)
*Settings: HTTP/SOCKS5 ports, bandwidth, LaunchAgent auto-start*

![I2P GUI Advanced Settings](screenshots/screenshot3_en.png)
*Advanced settings: tunnels, Address Book, and subscriptions*

<img src="screenshots/screenshot4_en.png" alt="I2P GUI Tray Menu" width="282" />

*Menu bar extras: quick actions and daemon state*

### 🖥️ **Main Window:**
- **📊 Server Status**: shows daemon state (running/stopped)
- **⏱️ Uptime**: I2P daemon uptime
- **🤝 Peers**: number of active connections
- **🌐 Network Statistics**: incoming/outgoing traffic, tunnels, routers

### 🎛️ **Control Panel:**
- **▶️ Start** - start I2P daemon with one click
- **⏹️ Stop** - proper daemon shutdown
- **🔄 Restart** - restart service
- **🔄 Refresh Status** - check current state
- **⚙️ Settings** - daemon configuration
- **🗑️ Clear Logs** - clear log history
- **🛠️ Tools** - access built-in I2P utilities

### ⚙️ **Settings:**
- **🌐 Network Configuration**: HTTP and SOCKS5 proxy port management
- **⚡ Bandwidth**: network speed selection (L/O/P/X)
- **🔧 Automation**: daemon auto-start configuration via LaunchAgent
- **🎨 Interface**: interface language management (Russian/English)
- **📱 Start Minimized**: application starts in tray without showing window
- **📊 Dynamic Values**: direct settings loading from config files

### 📝 **Logging:**
- **📋 Operation History**: detailed log of all actions
- **🔍 Filtering**: search by message type
- **💾 Export**: save logs to file
- **🗑️ Clear**: quick history cleanup

### 🛠️ **Built-in Tools Module:**
- **🔑 Key Generation**: create I2P destination keys with signature type selection
- **⛏️ Address Mining**: generate vanity addresses with custom prefixes
- **🔍 Key Information**: analyze existing keys and get destination addresses
- **📧 B33 Address**: calculate B33 addresses for encrypted leasesets
- **🌐 Domain Registration**: generate registration strings for .i2p domains
- **🏷️ 3LD Registration**: three-step registration for third-level domains
- **🔄 Domain Alias**: rebind domains to new keys
- **⏰ Offline Keys**: create temporary keys with limited validity
- **📊 Router Info**: analyze RouterInfo files with port/firewall/IPv6 flags
- **🔐 X25519 Keys**: generate encryption keys for authorized leasesets
- **📝 Base64 Encoding**: I2P-specific Base64 encoding/decoding
- **👥 Family Tool**: manage family certificates for router organization
- **✅ Host Verification**: verify signatures of host records
- **⚙️ Auto Configuration**: interactive terminal for i2pd.conf generation

---

## 🌐 Internationalization

### 🎯 **Supported Languages:**
- **🇷🇺 Russian** - primary interface language
- **🇺🇸 English** - full English localization

### 🔄 **Smart Language Switching:**
- **Automatic restart** when changing language
- **Daemon preservation** - daemon continues running during restart
- **Proper window closing** - all modal windows close automatically
- **Instant application** - new language applies immediately after restart

### 📋 **Localized Elements:**
- ✅ All interface elements (buttons, menus, labels)
- ✅ Log messages
- ✅ Bandwidth settings
- ✅ Tray menu
- ✅ Dialogs and notifications

---

## 🏗️ Technical Architecture

### 🛠️ **Technology Stack:**
- **UI**: SwiftUI + macOS Design Guidelines
- **Language**: Swift 5.7+
- **Build Manager**: Swift Package Manager
- **Daemon**: i2pd 2.61 (embedded binary)
- **Dependencies**: Native macOS APIs
- **Localization**: NSLocalizedString + .lproj bundles

### 📦 **Application Structure:**
```
I2P Daemon GUI.app/
├── Contents/
│   ├── Info.plist              # Metadata (version 2.61)
│   ├── MacOS/
│   │   └── I2P Daemon GUI       # GUI executable (1.5MB)
│   └── Resources/
│       ├── I2P-GUI.icns         # Application icon
│       ├── i2pd                  # Daemon binary (29MB)
│       ├── tools/                # Built-in I2P utilities
│       │   ├── keygen            # Key generation utility
│       │   ├── vain              # Address mining utility
│       │   ├── keyinfo           # Key information utility
│       │   ├── b33address        # B33 address calculator
│       │   ├── regaddr           # Domain registration utility
│       │   ├── regaddr_3ld       # Third-level domain registration
│       │   ├── regaddralias      # Domain alias utility
│       │   ├── offlinekeys       # Offline keys utility
│       │   ├── routerinfo        # Router info analyzer
│       │   ├── x25519            # X25519 key generator
│       │   ├── i2pbase64         # Base64 encoder/decoder
│       │   ├── famtool           # Family certificate tool
│       │   ├── verifyhost        # Host verification utility
│       │   └── autoconf          # Interactive config generator
│       ├── ru.lproj/            # Russian localization
│       │   └── Localizable.strings
│       └── en.lproj/            # English localization
│           └── Localizable.strings
```

**Total package size:** ~35MB

### 🔧 **System Components:**
- **I2pdManager**: daemon lifecycle manager with dynamic version fetching
- **ContentView**: main application interface with localization
- **SettingsView**: configuration panel with smart restart
- **StatusCard**: system status card
- **LogView**: logging system with localized messages
- **TrayManager**: system tray with localized menu
- **AppDelegate**: application lifecycle handling and smart exit
- **ToolsManager**: built-in utilities manager with process handling
- **ToolsView**: comprehensive tools interface with interactive terminal

---

## 🔨 Building from Source

### 📋 **Prerequisites:**
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Check Swift version
swift --version
```

### 🚀 **Build Instructions:**

1. **📥 Clone the repository:**
   ```bash
   git clone https://github.com/MetanoicArmor/gui-i2pd.git
   cd gui-i2pd
   ```

2. **🔨 Build the project:**
   ```bash
   # Apple Silicon (arm64)
   ./build-app-arm64.sh

   # Intel (x86_64)
   ./build-app-intel.sh
   ```

3. **🚀 Launch the application:**
   ```bash
   open "I2P Daemon GUI.app"
   ```

### 📜 **Available Commands:**
- `./build-app-simple.sh` - full .app package build with localization
- `swift build` - source code compilation only
- `swift test` - run tests (if available)

---

## 📊 Project Statistics

| Metric | Value |
|---------|----------|
| **Lines of Code** | 7,521 Swift |
| **Source Files** | 4 (`AppCore.swift`, `ToolsView.swift`, `LiquidGlassTheme.swift`, `TrayManager.swift`) |
| **Repository Size** | ~292MB (tracked files, without local build artifacts) |
| **Build Time** | ~10-20 seconds (incremental, by architecture) |
| **Compatibility** | macOS 14.0+ |
| **UI Framework Version** | SwiftUI |
| **Tray Status** | ✅ Stable |
| **Parsing Functions** | ✅ Fully functional |
| **Localization** | ✅ Russian + English |
| **Localization Keys** | 885 total (RU: 441, EN: 444) |
| **Built-in Tools** | ✅ 14 utilities |
| **Interactive Terminal** | ✅ Real-time I/O |

---

## 📄 License and Legal Information

The **Swift GUI source code** in this repository is distributed under the **BSD-3-Clause License**. See the `LICENSE` file.

**Bundled binaries** in release `.app` bundles are **not** authored here; they are built from upstream projects:

| Component | Source | License (upstream) |
|-----------|--------|-------------------|
| **`i2pd`** (daemon) | [PurpleI2P/i2pd](https://github.com/PurpleI2P/i2pd) | [BSD-3-Clause](https://github.com/PurpleI2P/i2pd/blob/openssl/LICENSE) (see file in repo) |
| **Tools** (`Contents/Resources/tools/`) | [PurpleI2P/i2pd-tools](https://github.com/PurpleI2P/i2pd-tools) | Per `LICENSE` in that repository |

### 🌐 **Technologies Used:**
- **I2P Network**: https://geti2p.net/ - anonymous network
- **i2pd daemon**: https://i2pd.website - official I2P protocol implementation; [PurpleI2P/i2pd](https://github.com/PurpleI2P/i2pd) on GitHub
- **Swift**: Apple programming language
- **SwiftUI**: Apple interface framework
- **NSLocalizedString**: Apple localization system
 
---

## ☕ Developer Support

If you like this project and it brings value, you can support its development by buying a virtual coffee:

<div align="center">

**☕ Buy developer a coffee:**

**⚡ TON:**
<div align="center">
<img src="ton_donation_qr.png" width="200">
</div>

### 📋 TON Address:

```
UQCsX_UVKylmlxb4dWZlXdmlyRzNm-kzUx7Ld1VQHk1ob0MY
```

*Thank you for your support! It motivates to continue working on the project* 🙏

</div>

---
## 🎉 Project Ready to Use!

<div align="center">

### 🚀 Direct Download:
[![Download I2P Daemon GUI.app](https://img.shields.io/badge/📦%20Download-I2P%20Daemon%20GUI.app-ff6b6b.svg?style=for-the-badge)](https://github.com/MetanoicArmor/gui-i2pd/releases/download/v2.61.0/I2P-Daemon-GUI-2.61.0.zip)

---

**I2P Daemon GUI** - elegant solution for macOS with minimal setup and maximum functionality.

*Created with ❤️ by Vade for privacy and anonymity community*

© 2026 Vade

</div>
