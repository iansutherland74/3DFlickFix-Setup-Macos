# 3DFlickFix macOS Setup Guide

This directory contains scripts to set up a mounted drive and/or DLNA server for accessing the 3DFlickFix collection on macOS.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Usage](#usage)
4. [Testing](#testing)
5. [Troubleshooting](#troubleshooting)
6. [Confirmed Working Versions](#confirmed-working-versions)

## Prerequisites

Before you begin, ensure you have the following:

- macOS 15.0.1 (Sequoia) or later. Earlier versions may work, but are not supported.
- An M1 or M2 chip. Intel chips or newer Apple Silicon chips may work, but are not supported.
- Administrator access to your Mac.
- Internet connection.

## Installation

1. **Install macFUSE:**
   macFUSE is required for mounting remote filesystems. You have two options:
   
   a. Download and install from the official website (recommended):
      - Visit [https://osxfuse.github.io](https://osxfuse.github.io) or [https://github.com/osxfuse/osxfuse/releases](https://github.com/osxfuse/osxfuse/releases)
      - Download and run the installer
      - Restart your computer after installation
   
   b. Use the provided disk image (may be out of date):
      - Locate the macFUSE disk image in the repository directory
      - Double-click to mount, then run the installer
      - Restart your computer after installation

2. **Install rclone:**
   rclone is required for mounting the remote drive and setting up the DLNA server. This repository includes a pre-compiled rclone binary for macOS, which you can use directly. If you prefer to use the latest version or a version for a different architecture:

   - Download the latest version from [https://rclone.org/downloads/](https://rclone.org/downloads/)
   - Extract the archive and move the `rclone` binary to the repository directory

   **DO NOT install rclone via Homebrew.** If you already have rclone installed via Homebrew, remove it before proceeding.

3. **Configure rclone:**
   Use the Rclone.conf that was given to you when you subscribed and replace the generic one in the working folder

4. **Ensure the scripts are executable:**
   ```
   chmod +x InstallServices.sh RemoveServices.sh
   ```

## Usage

1. **Run the installation script:**
   ```
   sudo ./InstallServices.sh
   ```

   The services will stay alive even after you close the terminal window. They will need to be restarted after a computer restart.

2. **Follow the on-screen prompts:**
   - Choose whether to mount the drive, set up a DLNA server, or both
   - If mounting, provide a name for the mount point

3. **Accessing the mounted drive:**
   - Open Finder
   - Navigate to the mount point you specified (e.g., `/path/to/repository/mountpoint`)

4. **Accessing the DLNA server:**
   - Use a DLNA-compatible device (smart TV, game console, VR device, mobile app) on the same network
   - Look for a device named "3DFlickFix" in your media player's source list

5. **Removing the services:**
   ```
   sudo ./RemoveServices.sh
   ```

   This will unload the services and kill rclone. It optionally remove logs and mount points. It will not remove macFUSE.

## Testing

To verify that everything is working correctly:

1. **Test file access:**
   Try opening a file from the mounted drive in Finder.

2. **Test DLNA streaming:**
   Use a DLNA-compatible player on another device to browse and play media.

   You can also test on the same device by checking if the DLNA server can be found in the VLC "Universal Plug'n'Play" device list.

## Troubleshooting

- **Mount fails to start:**
  - Ensure macFUSE is installed correctly
  - Check `Mountlog.txt` for error messages
  - Verify your `user` and `pass` in `rclone.conf`

- **DLNA server not visible:**
  - Check `DLNAlog.txt` for error messages
  - Ensure that your devices are on the same network
  - Verify that neither device is using a VPN
  - Grant rclone "Local Network" access in Security & Privacy
  - Disable network filters such as Little Snitch
  - Check your local network configuration, firewall, and router settings

## Confirmed Working Versions

- macOS: 15.0.1 (Sequoia) with M1 chip
- rclone: v1.68.1
- macFUSE: 4.8.2
- Playing videos streamed over DLNA: SKYBOX VR Player on Quest 3


sudo rclone mount --daemon --allow-other --vfs-read-chunk-size=32M --poll-interval 15s --vfs-cache-mode writes --disable About 3DFlickFix1
: /Users/sutherland/Downloads/3DFlickFix-MacOS/3DFlickFix1