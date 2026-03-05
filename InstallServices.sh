#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RCLONE_PATH=""
CONF_PATH="$SCRIPT_DIR/rclone.conf"
STATE_FILE="$SCRIPT_DIR/.3dflickfix_state"

REMOTE_NAME="3DFF"
DLNA_NAME="3DFlickFix"
DEFAULT_MOUNTPOINT="3DFF"
MODE=""
MOUNTPOINT=""
MOUNT_DIR=""
CONFIG_FILE=""
AUTO_YES=0
CONTINUE_WITHOUT_MACFUSE=0
FORCE_REINSTALL=0

DLNA_LABEL="com.3dflickfix.dlna"
MOUNT_LABEL="com.3dflickfix.mount"
DLNA_PLIST_FILE="$DLNA_LABEL.plist"
MOUNT_PLIST_FILE="$MOUNT_LABEL.plist"
DLNA_LOG="$SCRIPT_DIR/DLNAlog.txt"
MOUNT_LOG="$SCRIPT_DIR/Mountlog.txt"

usage() {
    cat <<'EOF'
Usage:
  sudo ./InstallServices.sh [options]

Options:
  --mode <mount|dlna|both>   Service mode. Defaults to interactive prompt.
    --mountpoint <name>        Mount directory name under script directory.
    --mount-dir <path>         Absolute directory where mountpoint should be created.
    --config-file <path>       Path to rclone.conf (default: script directory).
  --remote <name>            rclone remote name in rclone.conf (default: 3DFF).
  --dlna-name <name>         Name advertised on network (default: 3DFlickFix).
  --yes                      Non-interactive mode with sensible defaults.
  --continue-without-macfuse Continue even if macFUSE is missing.
    --force                    Reinstall services even if they already exist.
  -h, --help                 Show this help.

Examples:
  sudo ./InstallServices.sh --yes --mode both --mountpoint 3DFlickFix
  sudo ./InstallServices.sh --mode mount --mountpoint 3DFF
EOF
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo"
    exit 1
fi

INVOKING_USER="${SUDO_USER:-}"
if [ -z "$INVOKING_USER" ]; then
    INVOKING_USER=$(stat -f %Su /dev/console 2>/dev/null || true)
fi
if [ -z "$INVOKING_USER" ] || [ "$INVOKING_USER" = "root" ]; then
    echo "Could not detect the invoking user."
    echo "Run from a logged-in macOS user session."
    exit 1
fi

USER_HOME=$(dscl . -read /Users/"$INVOKING_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
if [ -z "$USER_HOME" ]; then
    USER_HOME=$(eval echo "~$INVOKING_USER")
fi

USER_UID=$(id -u "$INVOKING_USER")
LAUNCH_AGENTS_DIR="$USER_HOME/Library/LaunchAgents"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --mode)
            MODE="${2:-}"
            shift 2
            ;;
        --mountpoint)
            MOUNTPOINT="${2:-}"
            shift 2
            ;;
        --mount-dir)
            MOUNT_DIR="${2:-}"
            shift 2
            ;;
        --config-file)
            CONFIG_FILE="${2:-}"
            shift 2
            ;;
        --remote)
            REMOTE_NAME="${2:-}"
            shift 2
            ;;
        --dlna-name)
            DLNA_NAME="${2:-}"
            shift 2
            ;;
        --yes)
            AUTO_YES=1
            shift
            ;;
        --continue-without-macfuse)
            CONTINUE_WITHOUT_MACFUSE=1
            shift
            ;;
        --force)
            FORCE_REINSTALL=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [ -n "$CONFIG_FILE" ]; then
    CONF_PATH="$CONFIG_FILE"
fi

for candidate in "/usr/local/bin/rclone" "/opt/homebrew/bin/rclone" "$SCRIPT_DIR/rclone"; do
    if [ -x "$candidate" ]; then
        RCLONE_PATH="$candidate"
        break
    fi
done

if [ -z "$RCLONE_PATH" ]; then
    echo "rclone binary not found in /usr/local/bin, /opt/homebrew/bin, or app resources."
    exit 1
fi

if [ ! -f "$CONF_PATH" ]; then
    echo "rclone.conf not found at: $CONF_PATH"
    exit 1
fi

if [ ! -r "$CONF_PATH" ]; then
    echo "Warning: Config file is not readable at pre-check time: $CONF_PATH"
    echo "Continuing; rclone will perform final config validation."
elif ! grep -q "^\[$REMOTE_NAME\]" "$CONF_PATH"; then
    echo "Remote [$REMOTE_NAME] not found in $CONF_PATH"
    echo "Use --remote <name> or update rclone.conf"
    exit 1
fi

chmod +x "$RCLONE_PATH"

if ! "$RCLONE_PATH" listremotes --config "$CONF_PATH" >/tmp/3dflickfix-remotes.txt 2>/tmp/3dflickfix-remotes.err; then
    echo "Unable to read remotes from rclone config: $CONF_PATH"
    cat /tmp/3dflickfix-remotes.err 2>/dev/null || true
    exit 1
fi

if ! grep -q "^${REMOTE_NAME}:$" /tmp/3dflickfix-remotes.txt; then
    echo "Remote [$REMOTE_NAME] not found in rclone config."
    echo "This usually means the rclone login/config is missing or incorrect."
    echo "Use a valid rclone.conf or choose the correct remote name."
    exit 1
fi

if [ "$(uname -m)" = "arm64" ]; then
    RCLONE_ARCH=$(file -b "$RCLONE_PATH" 2>/dev/null || true)
    if echo "$RCLONE_ARCH" | grep -qi "x86_64" && ! /usr/bin/pgrep oahd >/dev/null 2>&1; then
        echo "Apple Silicon detected, but bundled rclone appears to be x86_64 and Rosetta is not running."
        echo "Install Rosetta or replace rclone with an arm64 build:"
        echo "  softwareupdate --install-rosetta --agree-to-license"
        exit 1
    fi
fi

check_macfuse() {
    if [ -e "/Library/Filesystems/macfuse.fs" ] || [ -e "/Library/Filesystems/osxfuse.fs" ]; then
        return 0
    fi

    for pkg in "com.github.osxfuse.pkg.Core" "io.macfuse.installer.pkg" "io.macfuse.installer" "com.github.macfuse"; do
        if pkgutil --pkg-info "$pkg" >/dev/null 2>&1; then
            return 0
        fi
    done

    echo "macFUSE is not installed. It is required for mount mode."
    echo "Install from https://osxfuse.github.io or use the bundled dmg in this directory."

    if [ "$AUTO_YES" -eq 1 ] || [ "$CONTINUE_WITHOUT_MACFUSE" -eq 1 ]; then
        if [ "$CONTINUE_WITHOUT_MACFUSE" -eq 1 ]; then
            echo "Continuing because --continue-without-macfuse was provided."
            return 0
        fi
        echo "Non-interactive mode cannot continue without macFUSE for mount mode."
        exit 1
    fi

    read -r -p "Continue anyway? (y/N): " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
        exit 1
    fi
}

create_launchd_service() {
    local label="$1"
    local plist_file="$2"
    local command_xml="$3"
    local plist_path="$LAUNCH_AGENTS_DIR/$plist_file"

    mkdir -p "$LAUNCH_AGENTS_DIR"

    cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
$command_xml
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>$SCRIPT_DIR</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF

    chown "$INVOKING_USER" "$plist_path"
    chmod 644 "$plist_path"

    /bin/launchctl bootout "gui/$USER_UID/$label" 2>/dev/null || true

    if ! /usr/bin/plutil -lint "$plist_path" >/dev/null; then
        echo "LaunchAgent plist is invalid: $plist_path"
        /usr/bin/plutil -lint "$plist_path" || true
        exit 1
    fi

    rm -f /tmp/3dflickfix-bootstrap.err

    # Try several compatible launchctl flows for newer/older macOS behavior.
    if /bin/launchctl asuser "$USER_UID" /bin/launchctl bootstrap "gui/$USER_UID" "$plist_path" 2>/tmp/3dflickfix-bootstrap.err; then
        :
    elif /bin/launchctl bootstrap "gui/$USER_UID" "$plist_path" 2>>/tmp/3dflickfix-bootstrap.err; then
        :
    elif su - "$INVOKING_USER" -c "launchctl bootstrap gui/$USER_UID '$plist_path'" 2>>/tmp/3dflickfix-bootstrap.err; then
        :
    elif su - "$INVOKING_USER" -c "launchctl load -w '$plist_path'" 2>>/tmp/3dflickfix-bootstrap.err; then
        :
    else
        echo "Failed to load LaunchAgent: $plist_path"
        echo "launchctl errors:"
        cat /tmp/3dflickfix-bootstrap.err 2>/dev/null || true
        exit 1
    fi

    /bin/launchctl asuser "$USER_UID" /bin/launchctl enable "gui/$USER_UID/$label" 2>/dev/null || /bin/launchctl enable "gui/$USER_UID/$label" 2>/dev/null || true
    /bin/launchctl asuser "$USER_UID" /bin/launchctl kickstart -k "gui/$USER_UID/$label" 2>/dev/null || /bin/launchctl kickstart -k "gui/$USER_UID/$label" 2>/dev/null || true
}

remove_service() {
    local label="$1"
    local plist_file="$2"
    local plist_path="$LAUNCH_AGENTS_DIR/$plist_file"
    if [ -f "$plist_path" ]; then
        /bin/launchctl bootout "gui/$USER_UID/$label" 2>/dev/null || true
        /bin/launchctl disable "gui/$USER_UID/$label" 2>/dev/null || true
        rm -f "$plist_path"
    fi
}

service_exists() {
    local label="$1"
    local plist_file="$2"
    local plist_path="$LAUNCH_AGENTS_DIR/$plist_file"

    if [ -f "$plist_path" ]; then
        return 0
    fi

    if /bin/launchctl print "gui/$USER_UID/$label" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

mount_drive() {
    check_macfuse

    local mountpoint="$1"
    local base_dir="$SCRIPT_DIR"
    if [ -n "$MOUNT_DIR" ]; then
        base_dir="$MOUNT_DIR"
    fi
    local mount_dir="$base_dir/$mountpoint"

    touch "$MOUNT_LOG"
    chown "$INVOKING_USER" "$MOUNT_LOG"
    chmod 644 "$MOUNT_LOG"

    if service_exists "$MOUNT_LABEL" "$MOUNT_PLIST_FILE" && [ "$FORCE_REINSTALL" -eq 0 ]; then
        echo "Mount service already exists. Skipping install (use --force to reinstall)."
        return 0
    fi

    remove_service "$MOUNT_LABEL" "$MOUNT_PLIST_FILE"

    mkdir -p "$mount_dir"
    chown "$INVOKING_USER" "$mount_dir"

    local mount_cmd="        <string>$RCLONE_PATH</string>
        <string>mount</string>
        <string>$REMOTE_NAME:</string>
        <string>$mount_dir</string>
        <string>--allow-other</string>
        <string>--dir-cache-time</string>
        <string>72h</string>
        <string>--drive-chunk-size</string>
        <string>64M</string>
        <string>--log-level</string>
        <string>INFO</string>
        <string>--vfs-read-chunk-size</string>
        <string>32M</string>
        <string>--vfs-read-chunk-size-limit</string>
        <string>off</string>
        <string>--config</string>
        <string>$CONF_PATH</string>
        <string>--log-file</string>
        <string>$MOUNT_LOG</string>
        <string>--vfs-cache-mode</string>
        <string>full</string>"

    create_launchd_service "$MOUNT_LABEL" "$MOUNT_PLIST_FILE" "$mount_cmd"
    echo "Drive mount service installed: $mount_dir"

    {
        printf 'REMOTE_NAME=%q\n' "$REMOTE_NAME"
        printf 'MOUNTPOINT=%q\n' "$mountpoint"
        printf 'MOUNT_DIR=%q\n' "$base_dir"
    } > "$STATE_FILE"
    chown "$INVOKING_USER" "$STATE_FILE" 2>/dev/null || true
}

setup_dlna() {
    if service_exists "$DLNA_LABEL" "$DLNA_PLIST_FILE" && [ "$FORCE_REINSTALL" -eq 0 ]; then
        echo "DLNA service already exists. Skipping install (use --force to reinstall)."
        return 0
    fi

    remove_service "$DLNA_LABEL" "$DLNA_PLIST_FILE"

    touch "$DLNA_LOG"
    chown "$INVOKING_USER" "$DLNA_LOG"
    chmod 644 "$DLNA_LOG"

    local dlna_cmd="        <string>$RCLONE_PATH</string>
        <string>serve</string>
        <string>dlna</string>
        <string>$REMOTE_NAME:</string>
        <string>--name</string>
        <string>$DLNA_NAME</string>
        <string>--dir-cache-time</string>
        <string>72h</string>
        <string>--drive-chunk-size</string>
        <string>64M</string>
        <string>--log-level</string>
        <string>INFO</string>
        <string>--vfs-read-chunk-size</string>
        <string>32M</string>
        <string>--vfs-read-chunk-size-limit</string>
        <string>off</string>
        <string>--config</string>
        <string>$CONF_PATH</string>
        <string>--log-file</string>
        <string>$DLNA_LOG</string>
        <string>--vfs-cache-mode</string>
        <string>full</string>"

    create_launchd_service "$DLNA_LABEL" "$DLNA_PLIST_FILE" "$dlna_cmd"
    echo "DLNA service installed: $DLNA_NAME"
}

if [ -z "$MODE" ]; then
    if [ "$AUTO_YES" -eq 1 ]; then
        MODE="both"
    else
        echo "Please choose an option:"
        echo "1. Mount the collection as a drive"
        echo "2. Set up a DLNA server on your local network"
        echo "3. Both"
        read -r -p "Enter your choice (1/2/3): " choice
        case "$choice" in
            1) MODE="mount" ;;
            2) MODE="dlna" ;;
            3) MODE="both" ;;
            *)
                echo "Invalid choice. Exiting."
                exit 1
                ;;
        esac
    fi
fi

case "$MODE" in
    mount|dlna|both) ;;
    *)
        echo "Invalid --mode '$MODE'. Use mount, dlna, or both."
        exit 1
        ;;
esac

if [ -z "$MOUNTPOINT" ]; then
    if [ "$AUTO_YES" -eq 1 ]; then
        MOUNTPOINT="$DEFAULT_MOUNTPOINT"
    elif [ "$MODE" = "mount" ] || [ "$MODE" = "both" ]; then
        read -r -p "Mountpoint name [$DEFAULT_MOUNTPOINT]: " MOUNTPOINT
        MOUNTPOINT=${MOUNTPOINT:-$DEFAULT_MOUNTPOINT}
    fi
fi

if [ "$MODE" = "mount" ] || [ "$MODE" = "both" ]; then
    if [ -z "$MOUNTPOINT" ]; then
        echo "Mount mode requires a mountpoint."
        exit 1
    fi
fi

echo "Starting setup for user: $INVOKING_USER"
echo "Mode: $MODE"
echo "Remote: $REMOTE_NAME"
if [ -n "$MOUNTPOINT" ]; then
    echo "Mountpoint: $MOUNTPOINT"
fi

case "$MODE" in
    mount)
        mount_drive "$MOUNTPOINT"
        ;;
    dlna)
        setup_dlna
        ;;
    both)
        mount_drive "$MOUNTPOINT"
        setup_dlna
        ;;
esac

echo "Waiting for services to start..."
sleep 4

echo "Checking service status..."
if [ "$MODE" = "mount" ] || [ "$MODE" = "both" ]; then
    if pgrep -f "rclone.*mount.*$REMOTE_NAME:" >/dev/null 2>&1; then
        echo "Mount service is running"
    else
        echo "Warning: Mount service may not be running. Check $MOUNT_LOG"
    fi
fi

if [ "$MODE" = "dlna" ] || [ "$MODE" = "both" ]; then
    if pgrep -f "rclone.*serve.*dlna.*$REMOTE_NAME:" >/dev/null 2>&1; then
        echo "DLNA service is running"
    else
        echo "Warning: DLNA service may not be running. Check $DLNA_LOG"
    fi
fi

echo "Setup completed."
