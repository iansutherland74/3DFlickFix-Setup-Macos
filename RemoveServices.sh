#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STATE_FILE="$SCRIPT_DIR/.3dflickfix_state"

DLNA_LABEL="com.3dflickfix.dlna"
MOUNT_LABEL="com.3dflickfix.mount"
DLNA_PLIST_FILE="$DLNA_LABEL.plist"
MOUNT_PLIST_FILE="$MOUNT_LABEL.plist"
DLNA_LOG="$SCRIPT_DIR/DLNAlog.txt"
MOUNT_LOG="$SCRIPT_DIR/Mountlog.txt"

AUTO_YES=0
CLEAN_LOGS=0
REMOVE_MOUNTPOINT=0
KILL_RCLONE=1
MOUNTPOINT=""
MOUNT_BASE_DIR="$SCRIPT_DIR"

usage() {
    cat <<'EOF'
Usage:
  sudo ./RemoveServices.sh [options]

Options:
  --yes                     Non-interactive mode.
  --clean-logs              Remove DLNAlog.txt and Mountlog.txt.
  --remove-mountpoint       Remove mountpoint directory.
  --mountpoint <name>       Mountpoint directory name under script directory.
  --no-kill-rclone          Do not kill remaining rclone processes.
  -h, --help                Show this help.

Examples:
  sudo ./RemoveServices.sh --yes --clean-logs --remove-mountpoint
  sudo ./RemoveServices.sh --mountpoint 3DFF --remove-mountpoint
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
        --yes)
            AUTO_YES=1
            shift
            ;;
        --clean-logs)
            CLEAN_LOGS=1
            shift
            ;;
        --remove-mountpoint)
            REMOVE_MOUNTPOINT=1
            shift
            ;;
        --mountpoint)
            MOUNTPOINT="${2:-}"
            shift 2
            ;;
        --no-kill-rclone)
            KILL_RCLONE=0
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

if [ -z "$MOUNTPOINT" ] && [ -f "$STATE_FILE" ]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE" || true
    MOUNTPOINT="${MOUNTPOINT:-}"
    MOUNT_BASE_DIR="${MOUNT_DIR:-$SCRIPT_DIR}"
fi

remove_service() {
    local label="$1"
    local plist_file="$2"
    local plist_path="$LAUNCH_AGENTS_DIR/$plist_file"

    /bin/launchctl bootout "gui/$USER_UID/$label" 2>/dev/null || true
    /bin/launchctl disable "gui/$USER_UID/$label" 2>/dev/null || true

    if [ -f "$plist_path" ]; then
        rm -f "$plist_path"
        echo "Removed $plist_file"
    else
        echo "$plist_file not found (already removed)."
    fi
}

remove_service "$MOUNT_LABEL" "$MOUNT_PLIST_FILE"
remove_service "$DLNA_LABEL" "$DLNA_PLIST_FILE"

if [ "$REMOVE_MOUNTPOINT" -eq 0 ] && [ "$AUTO_YES" -eq 0 ]; then
    read -r -p "Remove mountpoint directory too? (y/N): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        REMOVE_MOUNTPOINT=1
    fi
fi

if [ "$REMOVE_MOUNTPOINT" -eq 1 ]; then
    if [ -n "$MOUNTPOINT" ] && [ -d "$MOUNT_BASE_DIR/$MOUNTPOINT" ]; then
        rm -rf "$MOUNT_BASE_DIR/$MOUNTPOINT"
        echo "Removed mountpoint: $MOUNT_BASE_DIR/$MOUNTPOINT"
    elif [ -n "$MOUNTPOINT" ]; then
        echo "Mountpoint not found: $MOUNT_BASE_DIR/$MOUNTPOINT"
    else
        echo "No mountpoint known. Use --mountpoint <name> to remove it."
    fi
fi

if [ "$CLEAN_LOGS" -eq 0 ] && [ "$AUTO_YES" -eq 0 ]; then
    read -r -p "Remove log files? (Y/n): " answer
    if [[ ! "$answer" =~ ^[Nn]$ ]]; then
        CLEAN_LOGS=1
    fi
fi

if [ "$CLEAN_LOGS" -eq 1 ]; then
    rm -f "$DLNA_LOG" "$MOUNT_LOG"
    echo "Logs removed."
fi

if [ "$KILL_RCLONE" -eq 1 ]; then
    pkill -f "rclone" >/dev/null 2>&1 || true
    echo "Stopped remaining rclone processes."
fi

rm -f "$STATE_FILE"

echo "Service removal completed."
