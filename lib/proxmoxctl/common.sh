#!/bin/bash

ENV_FILE="/etc/openclaw/proxmox.env"

if [[ ! -r "$ENV_FILE" ]]; then
    echo "Cannot read $ENV_FILE" >&2
    exit 1
fi

source "$ENV_FILE"

: "${PROXMOX_HOST:?PROXMOX_HOST is not set}"
: "${PROXMOX_NODE:?PROXMOX_NODE is not set}"
: "${PROXMOX_TOKEN_ID:?PROXMOX_TOKEN_ID is not set}"
: "${PROXMOX_TOKEN_SECRET:?PROXMOX_TOKEN_SECRET is not set}"

API="https://${PROXMOX_HOST}:8006/api2/json"
AUTH="Authorization: PVEAPIToken=${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}"
CURL_TLS_OPTIONS=()

if [[ -n "${PROXMOX_CA_FILE:-}" ]]; then
    if [[ ! -r "$PROXMOX_CA_FILE" ]]; then
        echo "Cannot read PROXMOX_CA_FILE: $PROXMOX_CA_FILE" >&2
        exit 1
    fi

    CURL_TLS_OPTIONS=(--cacert "$PROXMOX_CA_FILE")
fi

api_get() {
    curl -fsS "${CURL_TLS_OPTIONS[@]}" -H "$AUTH" "$1"
}

api_post() {
    local url="$1"
    shift

    curl -fsS "${CURL_TLS_OPTIONS[@]}" \
        -X POST \
        -H "$AUTH" \
        "$@" \
        "$url"
}

api_put() {
    local url="$1"
    shift

    curl -fsS "${CURL_TLS_OPTIONS[@]}" \
        -X PUT \
        -H "$AUTH" \
        "$@" \
        "$url"
}

resources() {
    api_get "$API/cluster/resources?type=vm"
}

resolve_guest() {
    local target="$1"

    resources | python3 -c '
import json
import sys

target = sys.argv[1].strip()
guests = json.load(sys.stdin).get("data", [])
match = None

if target.isdigit():
    vmid = int(target)

    for guest in guests:
        if guest.get("vmid") == vmid:
            match = guest
            break

else:
    matches = [
        guest
        for guest in guests
        if str(guest.get("name", "")).lower() == target.lower()
    ]

    if len(matches) == 1:
        match = matches[0]

    elif len(matches) > 1:
        print(
            "Multiple guests named {}".format(target),
            file=sys.stderr
        )
        sys.exit(2)

if match is None:
    print(
        "Guest not found: {}".format(target),
        file=sys.stderr
    )
    sys.exit(1)

guest_type = match.get("type")

if guest_type not in ("lxc", "qemu"):
    print(
        "Unsupported guest type: {}".format(guest_type),
        file=sys.stderr
    )
    sys.exit(1)

print("{}|{}|{}".format(
    guest_type,
    match.get("vmid"),
    match.get("name", "")
))
' "$target"
}

guest_info() {
    local target="$1"
    local resolved

    if ! resolved="$(resolve_guest "$target")"; then
        return 1
    fi

    IFS='|' read -r TYPE VMID NAME <<< "$resolved"
}

get_status_json() {
    local type="$1"
    local vmid="$2"

    api_get \
        "$API/nodes/${PROXMOX_NODE}/${type}/${vmid}/status/current"
}

get_status_field() {
    local type="$1"
    local vmid="$2"
    local field="$3"

    get_status_json "$type" "$vmid" | python3 -c '
import json
import sys

field = sys.argv[1]
data = json.load(sys.stdin).get("data", {})

value = data.get(field, "")

if value is None:
    value = ""

print(value)
' "$field"
}

get_config_json() {
    local type="$1"
    local vmid="$2"

    api_get \
        "$API/nodes/${PROXMOX_NODE}/${type}/${vmid}/config"
}

get_node_status_json() {
    api_get \
        "$API/nodes/${PROXMOX_NODE}/status"
}

validate_integer() {
    local value="$1"
    local description="$2"
    local minimum="${3:-1}"

    if [[ ! "$value" =~ ^[0-9]+$ ]] || (( value < minimum )); then
        echo \
            "$description must be an integer >= $minimum." \
            >&2
        return 1
    fi
}

timestamp_name() {
    date '+%Y%m%d-%H%M%S'
}

extract_upid() {
    python3 -c '
import json
import sys

value = json.load(sys.stdin).get("data")

if not value:
    sys.exit(1)

print(value)
'
}

wait_for_task() {
    local upid="$1"
    local timeout="${2:-1800}"

    local start
    local now
    local response
    local task_status
    local exit_status

    start=$(date +%s)

    while true; do

        response=$(
            api_get \
                "$API/nodes/${PROXMOX_NODE}/tasks/${upid}/status"
        )

        read -r task_status exit_status <<< "$(
            python3 -c '
import json
import sys

data = json.load(sys.stdin).get("data", {})

print(
    data.get("status", ""),
    data.get("exitstatus", "")
)
' <<< "$response"
        )"

        if [[ "$task_status" == "stopped" ]]; then

            if [[ -z "$exit_status" || "$exit_status" == "OK" ]]; then
                return 0
            fi

            echo \
                "Proxmox task failed: $exit_status" \
                >&2

            return 1
        fi

        now=$(date +%s)

        if (( now - start >= timeout )); then
            echo \
                "Timed out after ${timeout}s waiting for Proxmox task." \
                >&2
            return 1
        fi

        sleep 3
    done
}

wait_for_state() {
    local target="$1"
    local desired="$2"
    local timeout="${3:-180}"

    local start
    local now
    local current

    guest_info "$target"

    start=$(date +%s)

    echo \
        "Waiting for ${NAME:-$VMID} ($VMID) to become $desired..."

    while true; do

        current=$(
            get_status_field \
                "$TYPE" \
                "$VMID" \
                status
        )

        if [[ "$current" == "$desired" ]]; then
            echo \
                "${NAME:-$VMID} ($VMID) is $desired."
            return 0
        fi

        now=$(date +%s)

        if (( now - start >= timeout )); then
            echo \
                "Timed out after ${timeout}s waiting for ${NAME:-$VMID} ($VMID) to become $desired." \
                >&2
            return 1
        fi

        sleep 3
    done
}

usage() {
    cat <<'USAGE'
Usage:
  proxmoxctl list [--json]
  proxmoxctl status <VMID|name>
  proxmoxctl config <VMID|name>
  proxmoxctl guest-memory <VMID|name>
  proxmoxctl node-status --json

  proxmoxctl start <VMID|name> [timeout]
  proxmoxctl shutdown <VMID|name> [timeout]
  proxmoxctl reboot <VMID|name>
  proxmoxctl restart <VMID|name> [timeout]
  proxmoxctl wait <VMID|name> <running|stopped> [timeout]

  proxmoxctl snapshots <VMID|name>
  proxmoxctl snapshot <VMID|name> <snapshot-name> [description]

  proxmoxctl backup <VMID|name> [storage]

  proxmoxctl set-memory <VMID|name> <MB> [--no-snapshot]
  proxmoxctl set-cores <VMID|name> <count> [--no-snapshot]
USAGE
}
