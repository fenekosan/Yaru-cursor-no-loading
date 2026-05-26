#!/usr/bin/env bash
# yaru-cursor-no-loading — disable the animated "progress" cursor in Yaru
# by creating an override cursor theme that inherits Yaru and maps every
# "loading"-like cursor name to Yaru's static arrow.
#
# Why an override theme and not a gnome-shell extension?
#   On Wayland the cursor change comes from the launching app through the
#   wp-cursor-shape-v1 protocol, handled by Mutter in C code before any
#   JS-level signal fires — extensions cannot intercept it. The cursor
#   sprite, however, is resolved from whichever cursor theme is active,
#   so an override theme is the cleanest interception point.
#
# Usage:
#   ./yaru-cursor-no-loading.sh install   # create theme and activate it
#   ./yaru-cursor-no-loading.sh rollback  # restore previous theme and remove the override

set -euo pipefail

THEME=Yaru-cursor-no-loading
THEME_DIR="$HOME/.local/share/icons/$THEME"
YARU_CURSORS=/usr/share/icons/Yaru/cursors

# Persist the pre-install cursor theme in XDG_STATE_HOME rather than inside the
# theme directory itself, so the value survives the rollback's `rm -rf` and is
# also writable when the script is fetched via `curl | bash` (no local repo).
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/yaru-cursor-no-loading"
STATE_FILE="$STATE_DIR/previous-theme"

GSCHEMA=org.gnome.desktop.interface
GSKEY=cursor-theme

die() { echo "ERROR: $*" >&2; exit 1; }

install_theme() {
    command -v gsettings >/dev/null || die "gsettings not found."
    [ -d "$YARU_CURSORS" ]      || die "Yaru cursor theme not installed at $YARU_CURSORS"
    [ -f "$YARU_CURSORS/arrow" ] || die "Yaru's 'arrow' cursor sprite is missing"

    # index.theme/cursor.theme declare inheritance from Yaru, so every cursor
    # we do NOT override below will still be picked up from the original Yaru.
    mkdir -p "$THEME_DIR/cursors"
    cat > "$THEME_DIR/index.theme" <<EOF
[Icon Theme]
Name=$THEME
Comment=Yaru with progress/wait cursors replaced by the default arrow
Inherits=Yaru
EOF
    cat > "$THEME_DIR/cursor.theme" <<EOF
[Icon Theme]
Name=$THEME
Inherits=Yaru
EOF

    # Symlink every cursor name a toolkit may resolve as "loading":
    #   progress / wait        — wp-cursor-shape-v1 names (GTK4 on Wayland)
    #   left_ptr_watch         — legacy Xcursor name
    #   half-busy              — the actual animated sprite Yaru ships
    # …and the .ani variants used by some legacy lookups. All point at
    # Yaru's static arrow, so no animation is ever shown for these names.
    cd "$THEME_DIR/cursors"
    for name in progress wait left_ptr_watch half-busy \
                progress.ani wait.ani left_ptr_watch.ani half-busy.ani; do
        ln -sf "$YARU_CURSORS/arrow" "$name"
    done

    # Remember the previously active theme so rollback restores it exactly,
    # rather than resetting to whatever GNOME's hard-coded default happens
    # to be on this host (Adwaita on a vanilla install, Yaru on Ubuntu).
    mkdir -p "$STATE_DIR"
    local prev
    prev=$(gsettings get "$GSCHEMA" "$GSKEY")
    if [ "$prev" != "'$THEME'" ]; then
        printf '%s\n' "$prev" > "$STATE_FILE"
    fi

    gsettings set "$GSCHEMA" "$GSKEY" "$THEME"

    echo "Installed and applied cursor theme: $THEME"
    [ -f "$STATE_FILE" ] && echo "Previous theme saved for rollback: $(cat "$STATE_FILE")"
    echo "Already-running apps may keep the old cursor until restarted."
}

rollback() {
    command -v gsettings >/dev/null || die "gsettings not found."

    # Restore the recorded previous theme; fall back to gsettings reset
    # if no record exists (theme was activated via some other tool).
    if [ -f "$STATE_FILE" ]; then
        local prev
        prev=$(tr -d "'" < "$STATE_FILE")
        gsettings set "$GSCHEMA" "$GSKEY" "$prev"
        echo "Restored cursor-theme to: $prev"
        rm -f "$STATE_FILE"
        rmdir --ignore-fail-on-non-empty "$STATE_DIR" 2>/dev/null || true
    else
        gsettings reset "$GSCHEMA" "$GSKEY"
        echo "Reset cursor-theme to GNOME default (no previous-theme record found)."
    fi

    if [ -d "$THEME_DIR" ]; then
        rm -rf "$THEME_DIR"
        echo "Removed override theme: $THEME_DIR"
    fi
}

case "${1:-}" in
    install)  install_theme ;;
    rollback) rollback ;;
    *)
        cat <<EOF
Usage: $(basename "$0") {install|rollback}

  install   Create ~/.local/share/icons/$THEME and set it as the cursor theme.
  rollback  Restore the previously active cursor theme and remove the override.
EOF
        exit 2
        ;;
esac
