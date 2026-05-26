# Yaru-cursor-no-loading

Disable the animated "loading" cursor that the Yaru theme shows while
applications are starting up on Ubuntu (GNOME / Wayland).

The script creates a small override cursor theme that inherits everything
from Yaru, but redirects every cursor name a toolkit may resolve as
"loading" to Yaru's static arrow sprite. The Yaru theme itself is not
modified.

## Why an override theme instead of a GNOME Shell extension

On Wayland the loading cursor is requested by the launching application
through the [`wp-cursor-shape-v1`](https://wayland.app/protocols/cursor-shape-v1)
protocol. Mutter handles the request in C code and resolves the requested
shape (`progress`, `wait`, …) against the active cursor theme before any
signal reaches the GNOME Shell JavaScript layer. A Shell extension cannot
intercept the cursor change, but it can be neutralised by making the
active theme resolve those shapes to a non-animated sprite.

## What the script does

`install`:

1. Creates `~/.local/share/icons/Yaru-cursor-no-loading/` with
   `index.theme` and `cursor.theme` declaring `Inherits=Yaru`.
2. Inside `cursors/`, creates symlinks for every "loading"-like cursor
   name (`progress`, `wait`, `left_ptr_watch`, `half-busy`, and their
   `.ani` legacy variants) pointing at `/usr/share/icons/Yaru/cursors/arrow`.
3. Saves the previously active cursor theme to
   `$XDG_STATE_HOME/yaru-cursor-no-loading/previous-theme`
   (defaults to `~/.local/state/yaru-cursor-no-loading/previous-theme`).
4. Sets `org.gnome.desktop.interface cursor-theme` to
   `Yaru-cursor-no-loading` via `gsettings`.

`rollback`:

1. Reads the saved previous theme from the state file and restores it via
   `gsettings` (falls back to `gsettings reset` if the file is missing).
2. Removes the override theme directory and the state file.

Every cursor that is **not** in the override list (text, hand, resize
handles, etc.) is resolved through the `Inherits=Yaru` chain and looks
exactly as it did before.

State is kept under `XDG_STATE_HOME` rather than inside the theme
directory itself, so a single one-shot `curl … | bash` invocation can
still find the previous-theme record on rollback after the theme
directory has been removed.

## Requirements

* Ubuntu / any distribution that ships the Yaru cursor theme at
  `/usr/share/icons/Yaru/cursors/`.
* GNOME on Wayland (X11 also works — Mutter resolves the same theme).

## Install

One-shot, no clone needed:

```sh
curl -fsSL https://raw.githubusercontent.com/fenekosan/Yaru-cursor-no-loading/main/yaru-cursor-no-loading.sh \
    | bash -s -- install
```

Or from a clone:

```sh
git clone https://github.com/fenekosan/Yaru-cursor-no-loading.git
cd Yaru-cursor-no-loading
./yaru-cursor-no-loading.sh install
```

Verify:

```sh
gsettings get org.gnome.desktop.interface cursor-theme
# 'Yaru-cursor-no-loading'
```

Already-running applications may keep the old cursor sprite cached until
they are restarted (or after the next login).

## Rollback

```sh
curl -fsSL https://raw.githubusercontent.com/fenekosan/Yaru-cursor-no-loading/main/yaru-cursor-no-loading.sh \
    | bash -s -- rollback
```

Or from a clone:

```sh
./yaru-cursor-no-loading.sh rollback
```

This restores the exact cursor theme that was active before `install`
and deletes `~/.local/share/icons/Yaru-cursor-no-loading/` along with
the state file.
