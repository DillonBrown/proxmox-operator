#!/bin/bash

cmd_start() {
    local target="${2:?Usage: proxmoxctl start <VMID|name> [timeout]}"
    local timeout="${3:-180}"
    local current

    guest_info "$target"

    current=$(
        get_status_field \
            "$TYPE" \
            "$VMID" \
            status
    )

    if [[ "$current" == "running" ]]; then
        echo "${NAME:-$VMID} ($VMID) is already running."
        return 0
    fi

    echo "Starting ${NAME:-$VMID} ($VMID)..."

    api_post \
        "$API/nodes/${PROXMOX_NODE}/${TYPE}/${VMID}/status/start" \
        >/dev/null

    wait_for_state \
        "$VMID" \
        running \
        "$timeout"
}

cmd_shutdown() {
    local target="${2:?Usage: proxmoxctl shutdown <VMID|name> [timeout]}"
    local timeout="${3:-180}"
    local current

    guest_info "$target"

    current=$(
        get_status_field \
            "$TYPE" \
            "$VMID" \
            status
    )

    if [[ "$current" == "stopped" ]]; then
        echo "${NAME:-$VMID} ($VMID) is already stopped."
        return 0
    fi

    echo "Shutting down ${NAME:-$VMID} ($VMID)..."

    api_post \
        "$API/nodes/${PROXMOX_NODE}/${TYPE}/${VMID}/status/shutdown" \
        >/dev/null

    wait_for_state \
        "$VMID" \
        stopped \
        "$timeout"
}

cmd_reboot() {
    local target="${2:?Usage: proxmoxctl reboot <VMID|name>}"
    local current

    guest_info "$target"

    current=$(
        get_status_field \
            "$TYPE" \
            "$VMID" \
            status
    )

    if [[ "$current" != "running" ]]; then
        echo \
            "${NAME:-$VMID} ($VMID) is currently $current; cannot reboot it." \
            >&2
        return 1
    fi

    echo \
        "Sending reboot request to ${NAME:-$VMID} ($VMID)..."

    api_post \
        "$API/nodes/${PROXMOX_NODE}/${TYPE}/${VMID}/status/reboot" |
        python3 -m json.tool
}

cmd_restart() {
    local target="${2:?Usage: proxmoxctl restart <VMID|name> [timeout]}"
    local timeout="${3:-180}"

    local current
    local old_uptime
    local new_uptime
    local start
    local now

    guest_info "$target"

    current=$(
        get_status_field \
            "$TYPE" \
            "$VMID" \
            status
    )

    if [[ "$current" != "running" ]]; then
        echo \
            "${NAME:-$VMID} ($VMID) is currently $current; cannot reboot it." \
            >&2
        return 1
    fi

    old_uptime=$(
        get_status_field \
            "$TYPE" \
            "$VMID" \
            uptime
    )

    old_uptime="${old_uptime:-0}"

    if [[ ! "$old_uptime" =~ ^[0-9]+$ ]]; then
        echo \
            "Could not determine uptime for ${NAME:-$VMID} ($VMID)." \
            >&2
        return 1
    fi

    echo "Restarting ${NAME:-$VMID} ($VMID)..."

    api_post \
        "$API/nodes/${PROXMOX_NODE}/${TYPE}/${VMID}/status/reboot" \
        >/dev/null

    start=$(date +%s)

    while true; do

        current=$(
            get_status_field \
                "$TYPE" \
                "$VMID" \
                status
        )

        if [[ "$current" == "running" ]]; then

            new_uptime=$(
                get_status_field \
                    "$TYPE" \
                    "$VMID" \
                    uptime
            )

            new_uptime="${new_uptime:-0}"

            if [[ "$new_uptime" =~ ^[0-9]+$ ]] &&
               (( new_uptime < old_uptime )); then

                echo \
                    "${NAME:-$VMID} ($VMID) restarted successfully."

                echo \
                    "Current uptime: ${new_uptime}s"

                return 0
            fi
        fi

        now=$(date +%s)

        if (( now - start >= timeout )); then
            echo \
                "Timed out waiting for ${NAME:-$VMID} ($VMID) to restart." \
                >&2
            return 1
        fi

        sleep 3
    done
}

cmd_wait() {
    local target="${2:?Usage: proxmoxctl wait <VMID|name> <running|stopped> [timeout]}"
    local state="${3:?Usage: proxmoxctl wait <VMID|name> <running|stopped> [timeout]}"
    local timeout="${4:-180}"

    case "$state" in
        running|stopped)
            ;;
        *)
            echo \
                "State must be 'running' or 'stopped'." \
                >&2
            return 1
            ;;
    esac

    wait_for_state \
        "$target" \
        "$state" \
        "$timeout"
}
