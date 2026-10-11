#!/bin/bash
# Regression test for the popup size: opens and closes the ChatAI popup in the
# running Plasma session and checks that the size Plasma saves on every close
# never changes. See docs/POPUP_SIZE_BUGFIX.md.
#
#   tests/popup-size-regression.sh [cycles] [--fresh]
#
#   cycles   open/close cycles (default 20)
#   --fresh  restart plasmashell without Plasma's saved popup size first, the
#            state of a newly added widget (where the old code grew the popup);
#            the saved size is put back and plasmashell restarted at the end
#
# Needs a Plasma 6 session with ChatAI on a panel. The popup really opens on
# screen while the test runs. A temporary global shortcut is used to toggle it
# and is removed at the end, even on failure.

set -euo pipefail

cycles=20
fresh=false
for arg in "$@"; do
    case $arg in
        --fresh) fresh=true ;;
        ''|*[!0-9]*) echo "usage: $0 [cycles] [--fresh]" >&2; exit 2 ;;
        *) cycles=$arg ;;
    esac
done

appletsrc=plasma-org.kde.plasma.desktop-appletsrc
shortcut="Ctrl+Alt+Meta+F12"

evaluate() {
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1"
}

# "containment applet" of the first ChatAI widget on a panel
location=$(evaluate 'var r = ""; panels().forEach(function (p) { p.widgets().forEach(function (w) {
    if (!r && w.type === "ChatAI-Plasmoid") r = p.id + " " + w.id; }); }); print(r);')
if [ -z "$location" ]; then
    echo "No ChatAI widget found on a panel" >&2
    exit 2
fi
read -r containment applet <<< "$location"
action="activate widget $applet"

# Sets "entry" to the kconfig arguments of a widget setting: "popupWidth" (the
# applet's Configuration group, where Plasma keeps the popup size),
# "General/dialogWidth" (ChatAI's own settings) or "Shortcuts/global"
widget_entry() {
    entry=(--file "$appletsrc" --group Containments --group "$containment" --group Applets --group "$applet")
    case $1 in
        Shortcuts/*) entry+=(--group Shortcuts) ;;
        */*) entry+=(--group Configuration --group "${1%%/*}") ;;
        *) entry+=(--group Configuration) ;;
    esac
    entry+=(--key "${1##*/}")
}

config() {
    widget_entry "$1"
    kreadconfig6 "${entry[@]}"
}

write_config() {
    widget_entry "$1"
    kwriteconfig6 "${entry[@]}" "${@:2}"
}

set_shortcut() {
    evaluate "panels().forEach(function (p) { p.widgets().forEach(function (w) {
        if (w.id === $applet) w.globalShortcut = '$1'; }); });" > /dev/null
}

toggle() {
    qdbus6 org.kde.kglobalaccel /component/plasmashell org.kde.kglobalaccel.Component.invokeShortcut "$action" > /dev/null
}

restart_plasmashell() {
    # optional KEY=VALUE pairs to write while plasmashell is stopped ("" deletes)
    systemctl --user stop plasma-plasmashell
    local pair
    for pair in "$@"; do
        if [ -n "${pair#*=}" ]; then
            write_config "${pair%%=*}" "${pair#*=}"
        else
            write_config "${pair%%=*}" --delete
        fi
    done
    systemctl --user start plasma-plasmashell
    local i
    for i in $(seq 1 30); do
        evaluate 'print(1)' > /dev/null 2>&1 && break
        sleep 1
    done
    sleep 3
}

saved_width=$(config popupWidth)
saved_height=$(config popupHeight)
# Versions before the fix also write their own size here while the test runs
saved_dialog_width=$(config General/dialogWidth)
saved_dialog_height=$(config General/dialogHeight)
saved_shortcut=$(config Shortcuts/global)

cleanup() {
    set_shortcut "$saved_shortcut" || true
    if $fresh; then
        # plasmashell writes an empty "global=" back while running
        restart_plasmashell "popupWidth=$saved_width" "popupHeight=$saved_height" \
            "General/dialogWidth=$saved_dialog_width" "General/dialogHeight=$saved_dialog_height" \
            "Shortcuts/global=$saved_shortcut" || true
    fi
    if [ -z "$saved_shortcut" ]; then
        # kglobalaccel keeps the action in memory; editing its file is not enough
        qdbus6 org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.unregister plasmashell "$action" > /dev/null || true
    fi
}
trap cleanup EXIT

if $fresh; then
    restart_plasmashell popupWidth= popupHeight=
fi

set_shortcut "$shortcut"
for i in $(seq 1 30); do
    qdbus6 org.kde.kglobalaccel /component/plasmashell org.kde.kglobalaccel.Component.shortcutNames \
        | grep -q "$action" && break
    sleep 0.5
done

declare -A seen=()
first=""
for i in $(seq 1 "$cycles"); do
    toggle; sleep 1.5
    toggle; sleep 1
    size="$(config popupWidth)x$(config popupHeight)"
    printf '%3d %s\n' "$i" "$size"
    first=${first:-$size}
    seen[$size]=1
done

if [ "${#seen[@]}" -ne 1 ]; then
    echo "FAIL: the popup size changed across $cycles openings (first $first, last $size)" >&2
    exit 1
fi
echo "PASS: $cycles openings, size $first every time"
