# 🚀 Antigravity Linux Installer & Updater

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20WSL2-orange.svg)](#-supported-environments--compatibility)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](#)

A fast, lightweight, and user-space installer and updater script for **Antigravity IDE** and **Antigravity 2.0 (Chat)** on Linux distributions from official `.tar.gz` tarballs.

---

## ✨ Features

- 👤 **Zero-Root / User-Space**: Installs cleanly into `~/Applications/` without requiring `sudo` or root privileges.
- 🔍 **Smart Auto-Detection**: Automatically inspects tarball contents to identify whether you are installing/updating the **IDE** or **Antigravity 2.0 (Chat)**.
- 🔄 **Seamless Upgrades (`-u` / `--update`)**: In-place replacement of application binaries while preserving user profiles, settings, extensions, and configurations.
- 📦 **Automated ASAR Icon Extraction**: Automatically unpacks Electron `.asar` bundles (`app.asar`) offline with built-in zero-dependency extractors (Python 3 / Node / native `asar`) to retrieve high-resolution official icons.
- 🎨 **Complete Desktop Integration**:
  - Uses the retrieved icon directly in generated XDG `.desktop` launchers for menus and docks.
  - Generates and installs multi-resolution icons (16x16 up to 1024x1024) into standard `hicolor` themes and `~/.local/share/pixmaps`.
  - Configures MIME type associations and URL protocol handlers.
- 💻 **CLI Integration**: Automatically adds binaries and wrapper scripts into `~/.local/bin/` (`antigravity-ide`, `antigravity`, `antigravity-chat`).
- 🛡️ **Electron Compatibility**: Configured with proper sandbox flags (`--no-sandbox`) to prevent common Electron launch issues on modern Linux kernels.

---

## 🖥️ Supported Environments & Compatibility

This script has been designed following standard **XDG Base Directory** specifications and POSIX/GNU conventions.

### 🐧 Supported Linux Distributions
| Distribution | Version / Compatibility | Notes |
| :--- | :--- | :--- |
| **Ubuntu** | 20.04 LTS, 22.04 LTS, **24.04 LTS** (Tested) | Full support |
| **Debian** | 11 (Bullseye), 12 (Bookworm), Sid | Full support |
| **Fedora** | 38, 39, 40+ | Full support |
| **Arch Linux / Manjaro** | Rolling Release / EndeavourOS | Full support |
| **Linux Mint / Pop!_OS** | All active releases | Full support |
| **openSUSE** | Leap 15.x, Tumbleweed | Full support |
| **RHEL / Rocky / AlmaLinux**| 8.x, 9.x+ | Full support |

### 🪟 Windows Subsystem for Linux (WSL)
- **WSL2 with WSLg** (Windows 11 / Windows 10 with GUI support): Fully supported.

### 🪟 Desktop Environments (DE) & Display Servers
- **GNOME** (Tested on GNOME 40 through GNOME 46+)
- **KDE Plasma** (5.x and 6.x)
- **XFCE**, **Cinnamon**, **MATE**, **LXQt**, **Budgie**, **Cosmic**
- **Wayland** Compositors (Sway, Hyprland, Wayfire) & **X11** sessions

### 📦 System Prerequisites
- **Standard tools** (usually pre-installed on every Linux distribution):
  - `bash` (version 4.0+)
  - `tar` & `gzip` / `xz`
  - `coreutils` (`mkdir`, `cp`, `mv`, `chmod`, `mktemp`)
- **Optional enhancement packages** (automatically used if present):
  - `imagemagick` (`convert`): for generating crisp icons across all pixel dimensions.
  - `desktop-file-utils` (`update-desktop-database`): for instantly refreshing application menus.
  - `gtk-update-icon-cache`: for rebuilding desktop icon caches.

---

## 📥 Installation & Setup

Clone the repository and make the script executable:

```bash
git clone https://github.com/granafilo/antigravity-install-script.git
cd antigravity-install-script
chmod +x install-antigravity.sh
```

*(Optional)* Create a symlink to run `install-antigravity` from anywhere:
```bash
mkdir -p ~/.local/bin
ln -sf "$(pwd)/install-antigravity.sh" ~/.local/bin/install-antigravity
```

---

## 🚀 Usage

### 1. Fresh Installation
Pass the downloaded tarball directly to the script:
```bash
./install-antigravity.sh ~/Downloads/"Antigravity IDE.tar.gz"
# or for the Chat / 2.0 app:
./install-antigravity.sh ~/Downloads/antigravity-linux-x64.tar.gz
```

### 2. Update an Existing Installation (`-u` / `--update`)
To update your current version with a newly downloaded tarball:
```bash
./install-antigravity.sh -u ~/Downloads/"Antigravity IDE.tar.gz"
```

### 3. Auto-Search Mode
If you run the script with `-u` (or without arguments), it will automatically look for available tarballs in your current directory, `~/Downloads`, and `~/Scaricati`:
```bash
./install-antigravity.sh -u
```

---

## ⚙️ Command-Line Options

| Option | Long Option | Description |
| :--- | :--- | :--- |
| `-u` | `--update` | Update mode: safely replaces application binaries while preserving configuration |
| `-i` | `--install` | Force installation mode (default behavior) |
| | `--ide` | Force target application type to **Antigravity IDE** |
| | `--chat`, `--2.0` | Force target application type to **Antigravity 2.0 (Chat)** |
| `-a <file>` | `--archive <file>` | Specify tarball archive path explicitly |
| `-h` | `--help` | Show help message and command examples |

---

## 📂 Installation Layout

The script installs all components into standard user-space locations:

```text
~ (Home Directory)
├── Applications/
│   ├── antigravity-ide/          # IDE binaries and runtime files
│   └── antigravity-chat/         # Chat / 2.0 binaries and runtime files
├── .local/
│   ├── bin/
│   │   ├── antigravity-ide       # Symlink to IDE executable
│   │   ├── antigravity           # Wrapper script for Chat / 2.0
│   │   └── antigravity-chat      # Compatibility symlink
│   └── share/
│       ├── applications/
│       │   ├── antigravity-ide.desktop
│       │   └── antigravity.desktop
│       └── icons/hicolor/*/apps/
│           ├── antigravity-ide.png
│           └── antigravity.png
```

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to open an issue or submit a pull request.

---

## 📜 License

This project is licensed under the **GNU General Public License v3.0 (GPLv3)**. See the [LICENSE](LICENSE) file for details.
