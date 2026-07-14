# Ashen

A monochrome Hyprland + Quickshell rice.

Hyprland · Quickshell · Kitty · Zsh + Powerlevel10k · PipeWire · matugen

---

<p align="center">
  <img src="https://github.com/user-attachments/assets/bbf668fc-dec3-41fc-b85b-98f470968e3b" width="49%" />
  <img src="https://github.com/user-attachments/assets/90688d3d-8a15-478d-bc21-243aa9ed7a71" width="49%" />
</p>
<p align="center">
  <img src="https://github.com/user-attachments/assets/2b3fd5b0-7691-42d9-9382-384ae500c49e" width="49%" />
  <img src="https://github.com/user-attachments/assets/4d62fbea-c0a3-459a-af28-d8ee252774bd" width="49%" />
</p>

## What's in it

A Quickshell shell (`quickshell/`) providing the bar, the panels and the lock
screen, driven by a Hyprland config written in **Lua** (`hypr/`).

- **Bar** — launcher, notifications, workspaces (incl. special workspaces), media,
  clock, tray, USB, screen recording, keyboard layout, network, bluetooth, volume,
  brightness, battery, power.
- **Panels** — every pill opens a panel that slides out and slides back in reverse.
- **Lock screen** — own `WlSessionLock` surface: padlock intro animation, PAM auth,
  blurred wallpaper, media card with a live Cava visualiser, battery + power profiles.
- **Launcher, clipboard, emoji picker, glyph picker, settings, wallpaper picker.**
- **Dynamic theming** — the wallpaper picker runs `matugen` over the chosen image and
  the whole shell re-colours from `~/.cache/ashen_scheme.json`.

## Requires

Everything below is what the shell actually shells out to. Missing one degrades a
specific feature rather than breaking the shell, except where noted.

### Official repos

```
hyprland kitty zsh stow git base-devel
qt6-base qt6-declarative qt6-5compat
pipewire pipewire-pulse pipewire-alsa wireplumber
networkmanager bluez bluez-utils udisks2 upower power-profiles-daemon
brightnessctl lm_sensors
wl-clipboard cliphist grim slurp wf-recorder
hypridle mpvpaper ffmpeg
nemo zenity fastfetch cava
sddm papirus-icon-theme ttf-jetbrains-mono-nerd
xdg-desktop-portal-hyprland polkit-gnome
```

`qt6-5compat` is **required**, not optional: the shell imports
`Qt5Compat.GraphicalEffects` for the blur and the rounded image masks.

### AUR (via `paru`, `yay`, …)

```
quickshell awww matugen grimblast-git
papirus-folders bibata-cursor-theme ttf-material-symbols-variable-git
```

- **quickshell** must be built with **PAM** and the **Hyprland** modules — the lock
  screen authenticates through `PamContext` (config `login`) and the bar reads
  workspaces over Hyprland IPC. `quickshell-allflags-git` also works.
- **ttf-material-symbols-variable-git** is required: every icon in the shell is a
  Material Symbols Rounded codepoint. Without it the bar renders empty boxes.
- **awww** paints static images and gifs, **mpvpaper** paints video wallpapers.

Plus [Oh My Zsh](https://ohmyz.sh) and [Powerlevel10k](https://github.com/romkatv/powerlevel10k),
which are not packaged — follow their own install instructions.

### What each command is used for

| Command | Feature that needs it |
|---|---|
| `hyprctl` | workspaces, window rules, keyboard layout switching |
| `wpctl` / `pactl` | volume, mute, output device, headphone detection |
| `brightnessctl` | brightness pill and OSD |
| `nmcli` | wifi/ethernet pill and network panel |
| `bluetoothctl` | bluetooth pill and panel |
| `powerprofilesctl` | power profile switcher (bar, settings, lock screen) |
| `upower` | battery time-remaining estimate |
| `udisksctl` / `lsblk` | USB pill: mount, unmount, eject |
| `cliphist` + `wl-copy` / `wl-paste` | clipboard history panel |
| `grimblast` | screenshots |
| `wf-recorder` + `ffmpeg` | screen recording pill |
| `cava` | audio visualiser (bar background, media panel, lock screen) |
| `awww` / `mpvpaper` / `matugen` | wallpapers and dynamic colour scheme |
| `hypridle` | idle → lock |
| `lm_sensors` | temperatures in the process panel |
| `nvidia-utils` (`nvidia-smi`) | dGPU stats — **only** read when the GPU is already awake |

## Install

```bash
git clone git@github.com:AdolfLecompte/ashen.git ~/ashen
cd ~/ashen
bash scripts/setup-system.sh
```

`setup-system.sh` installs the packages, symlinks the configs with `stow`, creates
the XDG folders, applies the GTK/icon/cursor settings and offers to enable the
system services. It is safe to re-run. Flags:

| Flag | Effect |
|---|---|
| `--no-packages` | skip installing anything |
| `--no-stow` | skip symlinking the configs |
| `--no-services` | skip `systemctl enable` |
| `-y`, `--yes` | never prompt |

To do it by hand instead:

```bash
stow -t ~ cava dconf fastfetch gtk hypr kitty matugen quickshell sddm zsh
```

Then set Zsh as your shell (`chsh -s $(which zsh)`), enable `NetworkManager`,
`bluetooth`, `power-profiles-daemon` and `sddm`, and log into the Hyprland session
through SDDM.

> **Clone to `~/ashen`.** `scripts/` is deliberately *not* stowed — the shell calls
> those scripts by absolute path (`$HOME/ashen/scripts/ashen-wallpaper.sh`), so the
> repo has to live at `~/ashen`.

> **The configs are stow-symlinked.** Editing `~/.config/hypr/…` or
> `~/.config/quickshell/ashen/…` edits the repo directly — there is no second copy
> to keep in sync.

> **XDG folders.** If your locale created localized user folders (`~/Imágenes`
> instead of `~/Pictures`), create the English ones too — the scripts expect
> `~/Pictures/Wallpapers`, `~/Pictures/Screenshots` and `~/Videos` literally,
> whatever the system language. `setup-system.sh` does this for you.

## Usage

| Keys | Action |
|---|---|
| `SUPER` (tap) | launcher |
| `SUPER + SHIFT + W` | wallpaper picker (drives dynamic theming) |
| `SUPER + I` | settings |
| `SUPER + T` | terminal |

The keyboard layout pill in the bar is **read-only**. Layouts are declared in
`hypr/.config/hypr/conf/input.lua` (`kb_layout = "latam,us"`) and switched from
**Settings → System → Keyboard**.

## Notes

- The Hyprland config is **Lua** (`hyprland.lua` + `conf/*.lua`), not `hyprland.conf`.
  `hyprctl keyword` does **not** work against it — use `hyprctl eval '<lua>'` to try
  things at runtime.
- Shell IPC: `qs -c ashen ipc show` lists every callable target.
- Reload the shell with `pkill quickshell; setsid nohup quickshell -c ashen &`.
- Window opacity: a `windowrule` opacity value is **multiplied** by
  `active_opacity`/`inactive_opacity` unless you append `override`. That is why the
  browser rule reads `opacity 0.85 override 0.80 override`.

## Status

Pre-1.0.0. The SDDM theme is in the repo but not enabled by default yet.
