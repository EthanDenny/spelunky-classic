#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRLCTL="${PRLCTL:-/Applications/Parallels Desktop.app/Contents/MacOS/prlctl}"
VM="${SPELUNKY_ORACLE_VM:-Windows 11}"
GUEST_DIR="${SPELUNKY_ORACLE_GUEST_DIR:-C:\\SpelunkyOracle}"
CAPTURE_DIR="$ROOT/test/original-oracle/captures"
CAPTURE_SHARE="SpelunkyOracleOutput"

usage() {
    printf '%s\n' \
        "Usage: tools/original_oracle.sh setup" \
        "       tools/original_oracle.sh launch" \
        "       tools/original_oracle.sh tap KEY [milliseconds]" \
        "       tools/original_oracle.sh hold-frames KEY FRAMES" \
        "       tools/original_oracle.sh chord-frames HELD_KEY KEY FRAMES" \
        "       tools/original_oracle.sh capture-held NAME KEY FRAMES" \
        "       tools/original_oracle.sh capture-after NAME KEY HELD_FRAMES WAIT_FRAMES" \
        "       tools/original_oracle.sh capture NAME" \
        "       tools/original_oracle.sh status" \
        "" \
        "Keys: left right up down jump action cycle run escape enter f4 f9"
}

keycode() {
    case "$1" in
        escape) printf '9' ;;
        enter) printf '36' ;;
        run) printf '50' ;;
        jump) printf '52' ;;
        action) printf '53' ;;
        cycle) printf '54' ;;
        f4) printf '70' ;;
        f9) printf '75' ;;
        up) printf '98' ;;
        left) printf '100' ;;
        right) printf '102' ;;
        down) printf '104' ;;
        *) printf 'Unknown oracle key: %s\n' "$1" >&2; exit 2 ;;
    esac
}

send_key() {
    local key="$1"
    local delay_ms="$2"
    "$PRLCTL" send-key-event "$VM" --key "$(keycode "$key")" --delay "$delay_ms"
}

focus_game() {
    "$PRLCTL" send-key-event "$VM" --key 64 --event press
    "$PRLCTL" send-key-event "$VM" --key 23 --delay 100
    "$PRLCTL" send-key-event "$VM" --key 64 --event release
}

setup() {
    mkdir -p "$CAPTURE_DIR"
    if "$PRLCTL" list "$VM" -i | grep -Fq "  $CAPTURE_SHARE ("; then
        "$PRLCTL" set "$VM" --shf-host on \
            --shf-host-set "$CAPTURE_SHARE" --path "$ROOT/test/original-oracle" --mode rw --enable
    else
        "$PRLCTL" set "$VM" --shf-host on \
            --shf-host-add "$CAPTURE_SHARE" --path "$ROOT/test/original-oracle" --mode rw --enable
    fi
    printf 'Oracle output share ready at %s\n' "$CAPTURE_DIR"
}

launch() {
    "$PRLCTL" exec "$VM" --current-user cmd.exe /d /s /c \
        "cd /d $GUEST_DIR & start \"\" Spelunky.exe"
}

copy_capture() {
    local name="$1"
    if [[ ! "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
        printf 'Capture name may only contain letters, numbers, dot, dash, and underscore.\n' >&2
        exit 2
    fi

    "$PRLCTL" exec "$VM" --current-user powershell.exe -NoProfile -Command \
        "\$source = Get-ChildItem '$GUEST_DIR\\screenshot*.png' | Sort-Object LastWriteTime -Descending | Select-Object -First 1; Copy-Item \$source.FullName '\\\\Mac\\$CAPTURE_SHARE\\captures\\$name.png' -Force"
    focus_game
    printf '%s\n' "$CAPTURE_DIR/$name.png"
}

capture() {
    send_key f9 100
    copy_capture "$1"
}

command="${1:-}"
case "$command" in
    setup)
        setup
        ;;
    launch)
        launch
        ;;
    tap)
        [[ $# -ge 2 ]] || { usage; exit 2; }
        send_key "$2" "${3:-100}"
        ;;
    hold-frames)
        [[ $# -eq 3 ]] || { usage; exit 2; }
        frames="$3"
        [[ "$frames" =~ ^[0-9]+$ ]] || { printf 'FRAMES must be a non-negative integer.\n' >&2; exit 2; }
        milliseconds=$(( (frames * 1000 + 15) / 30 ))
        send_key "$2" "$milliseconds"
        ;;
    chord-frames)
        [[ $# -eq 4 ]] || { usage; exit 2; }
        frames="$4"
        [[ "$frames" =~ ^[0-9]+$ ]] || { printf 'FRAMES must be a non-negative integer.\n' >&2; exit 2; }
        milliseconds=$(( (frames * 1000 + 15) / 30 ))
        "$PRLCTL" send-key-event "$VM" --key "$(keycode "$2")" --event press
        send_key "$3" "$milliseconds"
        "$PRLCTL" send-key-event "$VM" --key "$(keycode "$2")" --event release
        ;;
    capture-held)
        [[ $# -eq 4 ]] || { usage; exit 2; }
        frames="$4"
        [[ "$frames" =~ ^[0-9]+$ ]] || { printf 'FRAMES must be a non-negative integer.\n' >&2; exit 2; }
        milliseconds=$(( (frames * 1000 + 15) / 30 ))
        delay_seconds="$(awk -v milliseconds="$milliseconds" 'BEGIN { printf "%.3f", milliseconds / 1000 }')"
        "$PRLCTL" send-key-event "$VM" --key "$(keycode "$3")" --event press
        sleep "$delay_seconds"
        send_key f9 100
        "$PRLCTL" send-key-event "$VM" --key "$(keycode "$3")" --event release
        copy_capture "$2"
        ;;
    capture-after)
        [[ $# -eq 5 ]] || { usage; exit 2; }
        held_frames="$4"
        wait_frames="$5"
        [[ "$held_frames" =~ ^[0-9]+$ && "$wait_frames" =~ ^[0-9]+$ ]] || {
            printf 'HELD_FRAMES and WAIT_FRAMES must be non-negative integers.\n' >&2
            exit 2
        }
        held_ms=$(( (held_frames * 1000 + 15) / 30 ))
        wait_ms=$(( (wait_frames * 1000 + 15) / 30 ))
        held_seconds="$(awk -v milliseconds="$held_ms" 'BEGIN { printf "%.3f", milliseconds / 1000 }')"
        wait_seconds="$(awk -v milliseconds="$wait_ms" 'BEGIN { printf "%.3f", milliseconds / 1000 }')"
        "$PRLCTL" send-key-event "$VM" --key "$(keycode "$3")" --event press
        sleep "$held_seconds"
        "$PRLCTL" send-key-event "$VM" --key "$(keycode "$3")" --event release
        sleep "$wait_seconds"
        send_key f9 100
        copy_capture "$2"
        ;;
    capture)
        [[ $# -eq 2 ]] || { usage; exit 2; }
        capture "$2"
        ;;
    status)
        "$PRLCTL" status "$VM"
        "$PRLCTL" exec "$VM" --current-user cmd.exe /d /s /c \
            "tasklist /fi \"imagename eq Spelunky.exe\""
        ;;
    *)
        usage
        exit 2
        ;;
esac
